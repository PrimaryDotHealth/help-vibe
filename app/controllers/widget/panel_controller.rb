# The panel inside the iframe: suggestions, search, article.
class Widget::PanelController < Widget::BaseController
  def show
    @popular = Article.listed_for(viewer).includes(:versions).order(views: :desc, code: :asc).limit(5)
    @page = params[:page]
  end

  def search
    @query = params[:q].to_s.strip
    if (article = Article.find_by_code_query(@query)) && article.visible_to?(viewer)
      return redirect_to widget_article_path(article)
    end
    @results, @fuzzy = @query.present? ? SearchIndex.search(@query, viewer: viewer, limit: 10) : [ [], false ]
    @event = SearchEvent.log!(query: @query, results_count: @results.size, source: "widget", page_context: params[:page]) if @query.present?
  end

  # S08: a chromeless article for an iframe on one of our app's pages.
  def embed
    article
    render :embed unless performed?
  end

  def article
    @article = Article.find_by(slug: params[:slug]) || Article.find_by_code_query(params[:slug]) || raise(ActiveRecord::RecordNotFound)
    raise ActiveRecord::RecordNotFound unless @article.visible_to?(viewer) && (@version = @article.live_version)
    SearchEvent.find_by(id: params[:sid])&.clicked!(@article) if params[:sid]
    ViewEvent.create!(article: @article, version: @version, source: "widget", page_context: params[:page])
    Article.update_counters(@article.id, views: 1)
  end
end
