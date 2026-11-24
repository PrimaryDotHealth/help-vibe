# S03: an article's live version. Old slugs and codes redirect.
class Reader::ArticlesController < Reader::BaseController
  def show
    @article = Article.find_by(slug: params[:slug]) || redirect_target
    return if performed?
    raise ActiveRecord::RecordNotFound unless @article&.visible_to?(viewer)

    @version = if params[:number]
      @article.versions.find_by(number: params[:number], status: "published") || (Current.user&.editor? && @article.versions.find_by(number: params[:number]))
    else
      @article.live_version || (Current.user&.editor? && @article.versions.last)
    end
    raise ActiveRecord::RecordNotFound unless @version
    @preview = @version.status != "published"
    @older = !@preview && !@version.is_default
    @chapter = @article.main_category.chapter
    @siblings = Article.listed_for(viewer).where(main_category: [ @chapter ] + @chapter.children).includes(:versions).order(:code)

    @related = @article.related_for(viewer)
    record_view unless @preview
  end

  private
    def redirect_target
      if (r = SlugRedirect.find_by(from_path: "/a/#{params[:slug]}")) && r.article
        redirect_to article_path(r.article), status: :moved_permanently
      end
      nil
    end

    def record_view
      search = SearchEvent.find_by(id: params[:sid]) if params[:sid]
      search&.clicked!(@article)
      ViewEvent.create!(article: @article, version: @version, search_event: search, source: "kb", user: Current.user)
      Article.update_counters(@article.id, views: 1)
    end
end
