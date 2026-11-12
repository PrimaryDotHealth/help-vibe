# S04: search. A code ("SCH·07", "sch07") jumps straight to the article.
class Reader::SearchController < Reader::BaseController
  def index
    @query = params[:q].to_s.strip
    return if @query.blank?

    if (article = Article.find_by_code_query(@query)) && article.visible_to?(viewer)
      return redirect_to article_path(article)
    end

    @results, @fuzzy = SearchIndex.search(@query, viewer: viewer)
    @event = SearchEvent.log!(query: @query, results_count: @results.size, source: "kb", user: Current.user)
  end
end
