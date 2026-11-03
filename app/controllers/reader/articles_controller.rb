# S03: an article's live version. Old slugs and codes redirect.
class Reader::ArticlesController < Reader::BaseController
  def show
    @article = Article.find_by(slug: params[:slug]) || redirect_target
    return if performed?
    raise ActiveRecord::RecordNotFound unless @article&.visible_to?(viewer)

    @version = @article.live_version || (viewer&.editor? && @article.versions.last)
    raise ActiveRecord::RecordNotFound unless @version
    @preview = !@version.is_default
    @chapter = @article.main_category.chapter
    @siblings = Article.listed_for(viewer).where(main_category: [ @chapter ] + @chapter.children).includes(:versions).order(:code)

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
      ViewEvent.create!(article: @article, version: @version, search_event: search, source: "kb", user: viewer)
      Article.update_counters(@article.id, views: 1)
    end
end
