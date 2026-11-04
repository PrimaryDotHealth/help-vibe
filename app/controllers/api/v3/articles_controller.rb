class Api::V3::ArticlesController < Api::V3::BaseController
  include Rails.application.routes.url_helpers

  before_action :require_write, only: %i[create update destroy]

  def index
    scope = Article.listed_for(viewer).includes(:versions, :keywords, :main_category).order(:id)
    scope = scope.where(main_category_id: category_ids) if params[:category_id]
    scope = scope.where("articles.updated_at >= ?", parse_date(params[:updated_since])) if params[:updated_since]
    scope = scope.where("articles.updated_at <= ?", parse_date(params[:updated_upto])) if params[:updated_upto]
    scope = scope.where("articles.created_at >= ?", parse_date(params[:created_since])) if params[:created_since]
    if (code = params.dig(:filter, :accessibility))
      scope = scope.where(accessibility: ACCESSIBILITY_CODES.key(code.to_i))
    end
    render json: paginate(scope, :articles) { article_json(_1) }
  end

  def show
    id = params[:id].to_s
    article = Article.find_by(id: id.to_i) if id.match?(/\A\d+\z/)
    article ||= Article.find_by(slug: id) || Article.find_by_code_query(id)
    raise ActiveRecord::RecordNotFound unless article && Article.listed_for(viewer).exists?(article.id)
    render json: { article: article_json(article, answer: true) }
  end

  # POST /api/v3/articles  { article: { name, description, codename, body, published, category_ids, visibility_id } }
  def create
    attrs = article_params
    category = Category.find(Array(attrs[:category_ids]).first || raise(ActionController::BadRequest, "category_ids is required"))
    article = Article.start!(title: attrs[:name].presence || raise(ActionController::BadRequest, "name is required"),
                             category: category, author: nil, accessibility: accessibility_from(attrs) || "public")
    apply!(article, attrs)
    render json: { article: article_json(article.reload, answer: true, any_state: true) }, status: :created
  end

  def update
    article = find_for_write
    article.update!(accessibility: accessibility_from(article_params)) if accessibility_from(article_params)
    apply!(article, article_params)
    render json: { article: article_json(article.reload, answer: true, any_state: true) }
  end

  # Archives (hides everywhere, keeps history). Old links stop working.
  def destroy
    article = find_for_write
    Article.transaction do
      article.update!(archived_at: Time.current)
      article.versions.each { |v| SearchIndex.remove!(article, v.language) }
      Activity.record!(article, "delete", extra: { api_key: @api_key.prefix })
    end
    head :no_content
  end

  private
    def article_params = params.fetch(:article, params).permit(:name, :description, :codename, :body, :published, :visibility_id, category_ids: [])

    def accessibility_from(attrs) = attrs[:visibility_id].present? ? ACCESSIBILITY_CODES.key(attrs[:visibility_id].to_i) : nil

    def find_for_write
      Article.live.find_by(id: params[:id].to_i) || Article.live.find_by!(slug: params[:id])
    end

    def apply!(article, attrs)
      Article.transaction do
        article.update!(slug: attrs[:codename].to_s.parameterize) if attrs[:codename].present? && attrs[:codename].to_s.parameterize != article.slug
        if (ids = Array(attrs[:category_ids]).compact_blank).any?
          article.update!(main_category_id: ids.first.to_i)
          ArticleCategory.where(article: article).delete_all
          ids.drop(1).each { ArticleCategory.create!(article: article, category_id: _1.to_i) }
        end
        if attrs[:body] || attrs[:name] || attrs[:description]
          version = article.working_version!(author: nil)
          version.save_revision!(body: attrs[:body] || version.current_revision&.body_html.to_s, author: nil,
                                 base_revision_id: version.current_revision_id, title: attrs[:name], subtitle: attrs[:description])
        end
        if ActiveModel::Type::Boolean.new.cast(attrs[:published])
          draft = article.versions.reload.select(&:draft?).max_by(&:number)
          draft&.publish!(by: nil) if draft&.current_revision
        end
        Activity.record!(article, "update", extra: { api_key: @api_key.prefix })
      end
    end

    def category_ids
      id = params[:category_id].to_i
      [ id ] + Category.where(parent_id: id).pluck(:id)
    end

    # Helpjuice sends 20-09-2021; ISO 2021-09-20 works too.
    def parse_date(value)
      Date.strptime(value.to_s, "%d-%m-%Y")
    rescue Date::Error
      begin
        Date.iso8601(value.to_s)
      rescue Date::Error
        raise ActionController::BadRequest, "Dates look like 20-09-2021 or 2021-09-20"
      end
    end

    def article_json(article, answer: false, any_state: false)
      live = article.live_version
      version = live || (any_state && article.versions.max_by(&:number))
      json = {
        id: article.id, code: article.code, name: version.title, description: version.subtitle, codename: article.slug,
        accessibility: access_code(article.accessibility), published: live.present?, views: article.views,
        category_ids: [ article.main_category_id ], keywords: article.keywords.map { { id: _1.id, name: _1.name } },
        url: article_url(article, host: request.base_url), created_at: article.created_at, updated_at: article.updated_at
      }
      if answer && (rev = version.current_revision)
        json[:answer] = [ { body: rev.body_html, body_txt: rev.body_text, format: rev.body_format, updated_at: rev.created_at } ]
      end
      json
    end
end
