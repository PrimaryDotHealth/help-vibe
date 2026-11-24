require "json"

module Helpvibe
  module Importers
    # Imports a Helpjuice HTML export (the per-article .html files plus the
    # metadata.json that describes the chapter tree) from S3 or a local path.
    #
    # The location is either
    #   - a folder (s3://bucket/exports/helpjuice/): every .html under it, and
    #     every metadata*.json under it, or
    #   - a single article (s3://bucket/exports/testing/visby.html), with
    #     metadata: pointing at its metadata.json. Without metadata:, the
    #     nearest metadata.json in a parent folder is used.
    #
    # It shares the API importer's import_map rows (Helpjuice's own ids sit in
    # each file's <meta name="id">), so re-running updates instead of
    # duplicating, and a later API import updates the same chapters/articles.
    class HelpjuiceHtml < Helpjuice
      HTML = /\.html?\z/i
      METADATA = %r{(\A|/)metadata[^/]*\.json\z}i
      LOCATION = %r{\As3://([^/\s]+)/?(\S*)\z}
      JUNK = %r{(\A|/)(\.DS_Store|__MACOSX/)}

      class S3Store
        def initialize(bucket)
          require "aws-sdk-s3"
          @bucket = bucket
          @client = Aws::S3::Client.new(region: ENV["AWS_REGION"].presence || ENV["AWS_DEFAULT_REGION"].presence || "us-east-1")
        end

        def list(prefix)
          @client.list_objects_v2(bucket: @bucket, prefix: prefix).each do |page|
            page.contents.each { yield _1.key unless _1.key.end_with?("/") }
          end
        end

        def read(key) = @client.get_object(bucket: @bucket, key: key).body.read

        def exist?(key)
          @client.head_object(bucket: @bucket, key: key)
          true
        rescue Aws::S3::Errors::ServiceError
          false
        end

        def to_s = "s3://#{@bucket}"
      end

      # Same interface for a folder on this machine (rake task, tests).
      class DiskStore
        def list(prefix)
          Dir.glob(File.join(prefix, "**", "*")).sort.each { yield _1 if File.file?(_1) }
        end

        def read(path) = File.binread(path)
        def exist?(path) = File.file?(path)
        def to_s = "disk"
      end

      # "s3://bucket/some/key" -> [S3Store, "some/key"]; anything else is a local path.
      def self.locate(location)
        location = location.to_s.strip
        if (m = LOCATION.match(location))
          [ S3Store.new(m[1]), m[2] ]
        else
          [ DiskStore.new, File.expand_path(location) ]
        end
      end

      def initialize(location:, author:, metadata: nil, run: nil, images: true, log: ->(_) { })
        client = Helpjuice::Client.new(subdomain: "static", api_key: "", pause: 0) # only its image download is used
        super(client: client, author: author, run: run, users: false, images: images, log: log)
        @location = location
        @metadata = metadata
      end

      def call
        files = collect_files
        @rows = load_categories(files[:metadata])
        docs = parse_documents(files[:html])
        categories = import_categories(docs, folder: files[:folder])
        shells = docs.filter_map { |doc| guarded(doc) { [ doc, shell_for(doc, categories) ] } }
        index_links(shells)
        shells.each { |doc, article| guarded(doc) { import_html_body(doc, article) } }
        finish!("done")
      rescue StandardError => e
        finish!("failed", e)
        raise
      end

      private
        # One bad file is reported in the run's warnings, not the end of the import.
        def guarded(doc)
          yield
        rescue StandardError => e
          @stats["failed"] += 1
          @warnings << "#{doc[:key]}: #{e.message}"
          nil
        end

        # ---- finding the files
        def collect_files
          store, key = self.class.locate(@location)
          if key.match?(HTML)
            html = [ [ store, key ] ]
            metadata = metadata_from_option || nearest_metadata(store, key)
            folder = false
          else
            prefix = store.is_a?(S3Store) && key.present? ? key.chomp("/") + "/" : key
            keys = []
            store.list(prefix) { keys << _1 unless _1.match?(JUNK) }
            html = keys.grep(HTML).sort.map { [ store, _1 ] }
            metadata = metadata_from_option || keys.grep(METADATA).sort.map { [ store, _1 ] }
            metadata = nearest_metadata(store, prefix.chomp("/")) if metadata.empty?
            folder = true
          end
          raise "No .html files found at #{@location}" if html.empty?
          @warnings << "No metadata.json found: every article goes into the \"Imported, needs a chapter\" chapter" if metadata.empty?
          { html: html, metadata: metadata, folder: folder }
        end

        def metadata_from_option
          return if @metadata.blank?
          store, key = self.class.locate(@metadata)
          raise "metadata.json not found at #{@metadata}" unless store.exist?(key)
          [ [ store, key ] ]
        end

        # Walk up from an article (or folder) to the closest metadata.json.
        def nearest_metadata(store, key)
          dir = key
          5.times do
            dir = File.dirname(dir)
            candidate = dir == "." ? "metadata.json" : File.join(dir, "metadata.json")
            return [ [ store, candidate ] ] if store.exist?(candidate)
            break if dir == "." || dir == "/"
          end
          []
        end

        # ---- chapters: metadata.json is { codename => { id, name, parent_id, ... } }
        def load_categories(sources)
          rows = {}
          sources.each do |store, key|
            data = JSON.parse(store.read(key).dup.force_encoding("UTF-8").scrub)
            data.each_value { |row| rows[row["id"].to_s] ||= row if row.is_a?(Hash) && row["id"] }
          rescue JSON::ParserError => e
            @warnings << "#{key}: not valid JSON (#{e.message.lines.first.to_s.strip})"
          end
          rows
        end

        def import_categories(docs, folder:)
          wanted = folder ? @rows.keys : docs.filter_map { _1[:category_id] }.uniq
          wanted = wanted.flat_map { |id| ancestry(id) }.uniq
          depth = ->(id) { ancestry(id).size }
          @categories = {}
          wanted.sort_by { [ depth.(_1), @rows[_1]["position"].to_i ] }.each_with_index do |id, i|
            row = @rows[id]
            category = Category.find_by(id: mapped("category", id)) || Category.new
            parent = @categories[row["parent_id"].to_s] if row["parent_id"]
            accessibility = ACCESSIBILITY.fetch(row["accessibility"].to_i, "public")
            accessibility = "internal" if accessibility == "url_only"
            accessibility = parent.accessibility if parent && Category::ACCESSIBILITY.index(accessibility) < parent.restrictiveness
            category.assign_attributes(name: row["name"].to_s.strip.presence || "Untitled", description: row["description"].to_s,
                                       parent: parent, accessibility: accessibility, position: i,
                                       slug: category.slug.presence || unique_category_slug(row["codename"].presence || row["name"]),
                                       code: parent ? nil : (category.code || unique_code(row["name"])))
            category.archived_at ||= Time.current if row["archived"]
            category.save!
            remember!("category", id, category.id)
            @categories[id] = category
            @stats["categories"] += 1
          end
          @categories
        end

        # [root, ..., id]; stops at an unknown or cyclic parent.
        def ancestry(id, seen = [])
          row = @rows[id.to_s]
          return [] if row.nil? || seen.include?(id.to_s)
          parent = row["parent_id"]
          (parent ? ancestry(parent, seen + [ id.to_s ]) : []) + [ id.to_s ]
        end

        # ---- reading articles
        def parse_documents(files)
          by_codename = @rows.values.index_by { _1["codename"].to_s }
          docs = files.filter_map do |store, key|
            doc = parse(store.read(key), key, by_codename)
            if doc.nil?
              @stats["skipped"] += 1
              @warnings << "#{key}: empty, skipped"
            end
            doc
          end
          dupes = docs.group_by { _1[:id] }.select { _2.size > 1 }
          dupes.each { |id, copies| @warnings << "Helpjuice article #{id} appears #{copies.size} times (#{copies.map { _1[:key] }.join(", ")}): used the first" }
          docs.uniq { _1[:id] }
        end

        def parse(raw, key, by_codename)
          page = Nokogiri::HTML5(raw.dup.force_encoding("UTF-8").scrub)
          body = page.at_css("#hj-article-body") || page.at_css("article.question") || page.at_css("body")
          return if body.nil? || (body.text.strip.empty? && body.css("img, iframe, video").empty?)
          meta = ->(name) { page.at_css(%(meta[name="#{name}"]))&.[]("content").to_s.strip.presence }
          title = page.at_css(".article-name")&.text.to_s.strip.presence || meta.("name") || page.at_css("title")&.text.to_s.strip.presence || File.basename(key, ".*").tr("-_", " ")
          clean!(body, title)
          folder_category = File.dirname(key).split("/").reverse.filter_map { by_codename[_1]&.[]("id")&.to_s }.first
          {
            key: key, title: title, html: body.inner_html,
            id: meta.("id") || "file:#{Digest::SHA256.hexdigest(key)[0, 16]}",
            subtitle: page.at_css(".article-subtitle")&.text.to_s.strip.presence || meta.("description").to_s,
            codename: meta.("codename"), category_id: meta.("category_id") || folder_category,
            accessibility: meta.("accessibility") ? ACCESSIBILITY.fetch(meta.("accessibility").to_i, "internal") : "internal",
            published: meta.("published") != "false"
          }
        end

        # Helpjuice's editor leaves tab wrappers, drag handles and delete links
        # in the saved body, and the page title is repeated as the first heading.
        def clean!(body, title)
          body.css("a.delete-tab, i.fa-arrows-alt").each(&:remove)
          body.css(".f-tab").each { _1.replace(_1.children) }
          body.css("[id=isPasted]").each { _1.remove_attribute("id") }
          first = body.element_children.first
          first.remove if first&.name == "h1" && first.text.squish.casecmp?(title.squish)
        end

        # ---- writing articles
        def shell_for(doc, categories)
          category = categories[doc[:category_id].to_s]
          @warnings << "#{doc[:key]}: chapter #{doc[:category_id]} is not in metadata.json" if category.nil? && doc[:category_id]
          category ||= fallback_category
          article = Article.find_by(id: mapped("article", doc[:id]))
          if article.nil?
            article = Article.start!(title: doc[:title], category: category, author: @author, accessibility: doc[:accessibility])
            codename = doc[:codename]
            article.update!(slug: Article.unique_slug(codename)) if codename.present? && !Article.exists?(slug: codename.parameterize)
            @stats["articles_created"] += 1
          else
            article.update!(main_category: category, accessibility: doc[:accessibility])
            @stats["articles_updated"] += 1
          end
          @warnings << "#{article.code} \"#{doc[:title]}\" is private: share it with people or groups in helpvibe" if article.accessibility == "private"
          remember!("article", doc[:id], article.id)
          article
        end

        # Helpjuice article URLs end in the codename, or "<id>-<name>".
        def index_links(shells)
          @by_slug = shells.group_by { |doc, _| doc[:codename].to_s.downcase }.select { |k, v| k.present? && v.size == 1 }.transform_values { _1.first.last }
          @by_id = shells.to_h { |doc, article| [ doc[:id], article ] }
        end

        def import_html_body(doc, article)
          html = rewrite(doc[:html])
          existing = article.versions.select(&:draft?).max_by(&:number) || article.live_version
          if same_content?(existing, html, doc[:title], doc[:subtitle])
            version = existing
          else
            version = article.working_version!(author: @author)
            version.save_revision!(body: html, author: @author, base_revision_id: version.current_revision_id,
                                   title: doc[:title], subtitle: doc[:subtitle])
          end
          if doc[:published]
            version.publish!(by: @author) unless version.is_default
            @stats["published"] += 1
          else
            @stats["drafts"] += 1
          end
          say "#{article.code} #{doc[:title]}"
        end

        def rewrite(html)
          fragment = Nokogiri::HTML5.fragment(html)
          fragment.css("img[src]").each { rehost_image(_1) unless _1["src"].start_with?("data:") } if @images
          fragment.css("a[href]").each do |a|
            uri = URI(a["href"]) rescue next
            next unless uri.host.nil? || uri.host.end_with?("helpjuice.com")
            last = CGI.unescape(uri.path.to_s.split("/").last.to_s)
            target = @by_slug[last.downcase] || @by_id[last[/\A\d+/].to_s]
            next unless target
            a["href"] = "/a/#{target.slug}#{"##{uri.fragment}" if uri.fragment}"
            @stats["links_rewritten"] += 1
          end
          fragment.to_html
        end
    end
  end
end
