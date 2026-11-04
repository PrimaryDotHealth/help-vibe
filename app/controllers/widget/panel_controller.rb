# The panel inside the iframe: suggestions, search, article.
class Widget::PanelController < Widget::BaseController
  def show
    @page = params[:page]
    rule = ContextRule.for_page(@page)
    if rule
      visible = Article.listed_for(viewer).where(id: rule.article_ids).pluck(:id)
      @suggested = rule.articles.select { visible.include?(_1.id) }
    end
    @popular = Article.listed_for(viewer).includes(:versions).order(views: :desc, code: :asc).limit(5)
    @popular = @popular.where.not(id: @suggested.map(&:id)) if @suggested.present?
  end

  def search
    @query = params[:q].to_s.strip
    if (article = Article.find_by_code_query(@query)) && article.visible_to?(viewer)
      return redirect_to widget_article_path(article)
    end
    @results, @fuzzy = @query.present? ? SearchIndex.search(@query, viewer: viewer, limit: params[:suggest] ? 3 : 10) : [ [], false ]
    return render(:suggestions, layout: false) if params[:suggest]
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
