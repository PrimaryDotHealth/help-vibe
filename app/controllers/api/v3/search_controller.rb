class Api::V3::SearchController < Api::V3::BaseController
  include Rails.application.routes.url_helpers

  def index
    query = params[:query].to_s
    results, fuzzy = SearchIndex.search(query, viewer: viewer, category_id: params[:category_id].presence&.to_i, limit: limit)
    SearchEvent.log!(query: query, results_count: results.size, source: "api") if query.present?
    render json: {
      meta: { total_count: results.size, fuzzy: fuzzy },
      articles: results.map { { id: _1.article_id, code: _1.code, name: _1.title, description: _1.subtitle, codename: _1.slug,
                                 snippet: _1.snippet, url: article_url(_1.slug, host: request.base_url) } }
    }
  end
end
