require "net/http"
require "json"

module Helpvibe
  module Importers
    # Imports a Helpjuice knowledge base through its public API v3
    # (https://help.helpjuice.com/en_US/api-v3/using-api-v3) with our own key.
    #
    # Re-runnable: everything is matched through import_map, so a second run
    # updates instead of duplicating. Order:
    #   groups, users (optional) -> categories (chapters, with codes) ->
    #   article shells (so every new address is known) -> article bodies with
    #   images re-hosted and links to other Helpjuice articles rewritten ->
    #   redirects from old Helpjuice paths.
    #
    # Not in Helpjuice's API, so not imported: who a private article is shared
    # with (private articles come in visible to superadmins only, and are
    # listed in the run's warnings), comments, version history, analytics.
    class Helpjuice
      SOURCE = "helpjuice".freeze
      ACCESSIBILITY = { 1 => "public", 0 => "internal", 2 => "private", 4 => "url_only" }.freeze
      MAX_IMAGE_BYTES = 25.megabytes

      # Thin HTTP client for https://<subdomain>.helpjuice.com/api/v3, throttled
      # under Helpjuice's 100 requests/minute, with retries on 429 and 5xx.
      class Client
        def initialize(subdomain:, api_key:, pause: 0.65)
          @base = URI("https://#{subdomain}.helpjuice.com")
          @api_key = api_key
          @pause = pause
        end

        attr_reader :base

        def get(path, params = {})
          uri = URI.join(@base.to_s, "/api/v3/#{path}")
          uri.query = URI.encode_www_form(params) if params.any?
          attempts = 0
          loop do
            attempts += 1
            sleep @pause
            request = Net::HTTP::Get.new(uri, "Authorization" => @api_key, "Accept" => "application/json")
            response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 60) { _1.request(request) }
            case response.code.to_i
            when 200 then return JSON.parse(response.body)
            when 429, 500..599
              raise "Helpjuice #{path}: HTTP #{response.code} after #{attempts} tries" if attempts >= 5
              sleep [ response["Retry-After"].to_i, 2**attempts ].max
            else
              raise "Helpjuice #{path}: HTTP #{response.code} #{response.body.to_s[0, 200]}"
            end
          end
        end

        # Collections are paged: ?page=N&limit=1000, meta.total_pages.
        def each_page(path, key, params = {})
          page = 1
          loop do
            data = get(path, params.merge(page: page, limit: 1000))
            Array(data[key]).each { yield _1 }
            break if page >= data.dig("meta", "total_pages").to_i
            page += 1
          end
        end

        def download(url)
          uri = URI(url)
          return unless %w[http https].include?(uri.scheme)
          response = Net::HTTP.get_response(uri)
          response = Net::HTTP.get_response(URI(response["location"])) if response.is_a?(Net::HTTPRedirection) && response["location"]
          return unless response.is_a?(Net::HTTPSuccess) && response.body.bytesize <= MAX_IMAGE_BYTES
          [ response.body, response["content-type"].to_s.split(";").first ]
        rescue StandardError
          nil
        end
      end

      attr_reader :run

      def initialize(client:, author:, run: nil, users: false, images: true, log: ->(_) { })
        @client = client
        @author = author
        @users = users
        @images = images
        @log = log
        @run = run || ImportRun.create!(source: SOURCE, started_by: author)
        @stats = Hash.new(0)
        @warnings = []
        @article_paths = {}   # old Helpjuice path -> our article
      end

      def call
        import_groups
        import_users if @users
        categories = import_categories
        articles = import_article_shells(categories)
        articles.each { |source, article| import_body(source, article) }
        finish!("done")
      rescue StandardError => e
        finish!("failed", e)
        raise
      end

      private
        def say(message) = @log.call(message)

        def finish!(status, error = nil)
          @run.update!(status: status, finished_at: Time.current, error: error&.message,
                       stats: @stats.merge("warnings" => @warnings.first(200)))
        end

        def mapped(type, source_id) = ImportMap.find_by(source: SOURCE, source_type: type, source_id: source_id.to_s)&.local_id

        def remember!(type, source_id, local_id)
          ImportMap.upsert({ source: SOURCE, source_type: type, source_id: source_id.to_s, local_id: local_id, run_id: @run.id },
                           unique_by: %i[source source_type source_id])
        end

        # ---- groups and users
        def import_groups
          @client.each_page("groups", "groups") do |g|
            group = Group.find_by(id: mapped("group", g["id"])) || Group.find_or_initialize_by(name: g["name"])
            group.save! if group.new_record?
            remember!("group", g["id"], group.id)
            @stats["groups"] += 1
          end
        end

        def import_users
          @client.each_page("users", "users") do |u|
            email = u["email"].to_s.strip.downcase
            next if email.blank?
            user = User.find_or_initialize_by(email_address: email)
            if user.new_record?
              role = User::ROLES.include?(u["role_id"]) ? u["role_id"] : "viewer"
              user.assign_attributes(first_name: u["first_name"].to_s, last_name: u["last_name"].to_s, role: role,
                                     password: SecureRandom.base58(24))
              user.save!
              @stats["users_created"] += 1
            end
            remember!("user", u["id"] || email, user.id)
          end
        end

        # ---- categories -> chapters
        def import_categories
          rows = []
          @client.each_page("categories", "categories") { rows << _1 }
          by_id = rows.index_by { _1["id"] }
          depth = ->(row, seen = []) { (p = by_id[row["parent_id"]]) && !seen.include?(p["id"]) ? 1 + depth.(p, seen + [ row["id"] ]) : 0 }

          rows.sort_by { depth.(_1) }.each_with_index do |row, i|
            category = Category.find_by(id: mapped("category", row["id"])) || Category.new
            parent = Category.find_by(id: mapped("category", row["parent_id"])) if row["parent_id"]
            accessibility = ACCESSIBILITY.fetch(row["accessibility"].to_i, "public")
            accessibility = "internal" if accessibility == "url_only"
            if parent && Category::ACCESSIBILITY.index(accessibility) < parent.restrictiveness
              accessibility = parent.accessibility
            end
            category.assign_attributes(name: row["name"].to_s.strip.presence || "Untitled", description: row["description"].to_s,
                                       parent: parent, accessibility: accessibility, position: i,
                                       slug: category.slug.presence || unique_category_slug(row["codename"].presence || row["name"]),
                                       code: parent ? nil : (category.code || unique_code(row["name"])))
            category.save!
            remember!("category", row["id"], category.id)
            add_redirect(path_of(row["url"]), category: category)
            @stats["categories"] += 1
          end

          rows
        end

        def unique_category_slug(base)
          base = base.to_s.parameterize.presence || "chapter"
          slug = base
          n = 1
          slug = "#{base}-#{n += 1}" while Category.exists?(slug: slug)
          slug
        end

        # "Billing / Subscription" -> BIL, then BS, BILL, BSU... until free.
        def unique_code(name)
          words = name.to_s.upcase.scan(/[A-Z]+/)
          letters = words.join
          candidates = [ letters[0, 3], words.map { _1[0] }.join[0, 3], letters[0, 4], words.map { _1[0] }.join[0, 2], letters[0, 2] ]
          candidates += letters.chars.combination(2).first(50).map { (letters[0] + _1.join)[0, 3] }
          code = candidates.compact.uniq.find { _1.length.between?(2, 4) && !Category.exists?(code: _1) }
          code || loop { c = Array.new(3) { ("A".."Z").to_a.sample }.join; break c unless Category.exists?(code: c) }
        end

        # ---- articles
        def import_article_shells(categories)
          placement = Hash.new { |h, k| h[k] = [] } # article source id -> [category source ids], published first
          categories.each do |c|
            Array(c["published_questions"]).each { placement[_1["id"]] << c["id"] }
            Array(c["draft_questions"]).each { placement[_1["id"]] << c["id"] }
          end

          shells = []
          @client.each_page("articles", "articles") do |row|
            main_source = placement[row["id"]].first
            category = Category.find_by(id: mapped("category", main_source)) || fallback_category
            article = Article.find_by(id: mapped("article", row["id"]))
            if article.nil?
              article = Article.start!(title: row["name"].to_s.presence || "Untitled", category: category, author: @author,
                                       accessibility: ACCESSIBILITY.fetch(row["accessibility"].to_i, "public"))
              article.update!(slug: Article.unique_slug(row["codename"])) if row["codename"].present? && !Article.exists?(slug: row["codename"].to_s.parameterize)
              @stats["articles_created"] += 1
            else
              article.update!(main_category: category, accessibility: ACCESSIBILITY.fetch(row["accessibility"].to_i, article.accessibility))
              @stats["articles_updated"] += 1
            end
            @warnings << "#{article.code} \"#{row["name"]}\" is private: share it with people or groups in helpvibe" if article.accessibility == "private"
            article.update_columns(views: row["views"].to_i) if row["views"]
            also = placement[row["id"]].drop(1).filter_map { mapped("category", _1) }
            also.each { |cid| ArticleCategory.find_or_create_by!(article_id: article.id, category_id: cid) }
            remember!("article", row["id"], article.id)
            if (path = path_of(row["url"]))
              @article_paths[path] = article
              @article_paths[path.sub(%r{\A/[a-z]{2}_[A-Z]{2}}, "")] = article
            end
            @article_paths["/#{row["codename"]}"] = article if row["codename"].present?
            shells << [ row, article ]
          end
          shells
        end

        def fallback_category
          @fallback_category ||= Category.find_by(code: "IMP") ||
            Category.create!(name: "Imported, needs a chapter", code: "IMP", accessibility: "internal")
        end

        def import_body(row, article)
          answer = Array(row["answer"]).first || Array(@client.get("articles/#{row["id"]}")&.dig("article", "answer")).first
          html = answer&.dig("body").to_s
          html = rewrite(html)
          title = row["name"].to_s.presence || "Untitled"
          subtitle = row["description"].to_s
          existing = article.versions.select(&:draft?).max_by(&:number) || article.live_version
          if same_content?(existing, html, title, subtitle)
            version = existing
          else
            version = article.working_version!(author: @author)
            version.save_revision!(body: html, author: @author, base_revision_id: version.current_revision_id,
                                   title: title, subtitle: subtitle)
          end
          article.keyword_list = Array(row["keywords"]).map { _1["name"] }.join(", ") if row["keywords"]
          if row["published"] == false
            @stats["drafts"] += 1
          else
            version.publish!(by: @author) unless version.is_default
            @stats["published"] += 1
          end
          add_redirect(path_of(row["url"]), article: article)
          add_redirect(path_of(row["url"])&.sub(%r{\A/[a-z]{2}_[A-Z]{2}}, ""), article: article)
          say "#{article.code} #{title}"
        end

        # Compare through Action Text's normalisation, so a re-run with no
        # changes in Helpjuice creates no new versions.
        def same_content?(version, html, title, subtitle)
          rev = version&.current_revision
          rev.present? && version.title == title && version.subtitle.to_s == subtitle &&
            rev.body_html.strip == ActionText::Content.new(html).to_html.strip
        end

        # Re-host images, point links at our articles.
        def rewrite(html)
          doc = Nokogiri::HTML5.fragment(html)
          doc.css("img[src]").each { rehost_image(_1) } if @images
          doc.css("a[href]").each do |a|
            uri = URI(a["href"]) rescue next
            next unless uri.host.nil? || uri.host == @client.base.host
            target = @article_paths[uri.path] || @article_paths[uri.path.to_s.delete_suffix("/")]
            next unless target
            a["href"] = "/a/#{target.slug}#{"##{uri.fragment}" if uri.fragment}"
            @stats["links_rewritten"] += 1
          end
          doc.to_html
        end

        def rehost_image(img)
          src = img["src"].to_s
          src = URI.join(@client.base.to_s, src).to_s if src.start_with?("/")
          key = Digest::SHA256.hexdigest(src)
          blob = ActiveStorage::Blob.find_by(id: mapped("upload", key))
          unless blob
            body, type = @client.download(src)
            unless body && type.to_s.start_with?("image/")
              @warnings << "Image not downloaded: #{src}"
              return
            end
            filename = File.basename(URI(src).path).presence || "image"
            blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(body), filename: filename, content_type: type)
            remember!("upload", key, blob.id)
            @stats["images"] += 1
          end
          img.replace(Nokogiri::HTML5.fragment(ActionText::Attachment.from_attachable(blob, caption: img["alt"].presence).to_html))
        end

        def path_of(url)
          URI(url.to_s).path.presence if url.present?
        rescue URI::InvalidURIError
          nil
        end

        def add_redirect(path, article: nil, category: nil)
          return if path.blank? || path == "/"
          return if (article && path == "/a/#{article.slug}") || (category && path == "/c/#{category.slug}")
          SlugRedirect.upsert({ from_path: path, article_id: article&.id, category_id: category&.id }, unique_by: :from_path)
          @stats["redirects"] += 1
        end
    end
  end
end
