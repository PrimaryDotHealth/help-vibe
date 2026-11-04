class Api::V3::ArticlesController < Api::V3::BaseController
  include Rails.application.routes.url_helpers

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

  private
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

    def article_json(article, answer: false)
      version = article.live_version
      json = {
        id: article.id, code: article.code, name: version.title, description: version.subtitle, codename: article.slug,
        accessibility: access_code(article.accessibility), published: true, views: article.views,
        category_ids: [ article.main_category_id ], keywords: article.keywords.map { { id: _1.id, name: _1.name } },
        url: article_url(article, host: request.base_url), created_at: article.created_at, updated_at: article.updated_at
      }
      if answer && (rev = version.current_revision)
        json[:answer] = [ { body: rev.body_html, body_txt: rev.body_text, format: rev.body_format, updated_at: rev.created_at } ]
      end
      json
    end
end
