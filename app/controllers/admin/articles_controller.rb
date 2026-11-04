# S11 article list and S12 editor.
class Admin::ArticlesController < Admin::BaseController
  STATUSES = %w[all drafts live review].freeze

  def index
    @status = STATUSES.include?(params[:status]) ? params[:status] : "all"
    scope = Article.live.includes(:versions, :main_category, :created_by).order(updated_at: :desc)
    scope = scope.published if @status == "live"
    scope = scope.where(id: ArticleVersion.where(status: "draft").select(:article_id)) if @status == "drafts"
    scope = scope.where(id: ArticleVersion.where(id: Review.awaiting(Current.user).select(:version_id)).select(:article_id)) if @status == "review"
    scope = scope.where("articles.code ilike :q or articles.slug ilike :q", q: "%#{Article.sanitize_sql_like(params[:q])}%") if params[:q].present?
    @articles = scope.limit(200)
    @counts = { "all" => Article.live.count, "drafts" => Article.live.where(id: ArticleVersion.where(status: "draft").select(:article_id)).count, "live" => Article.live.published.count,
                "review" => Review.awaiting(Current.user).count }
  end

  def new
    @chapters = Category.chapters
  end

  def create
    category = Category.find(params.require(:article)[:main_category_id])
    @article = Article.start!(title: params[:article][:title].presence || "Untitled", category: category,
                              author: Current.user, accessibility: params[:article][:accessibility].presence || "public")
    redirect_to edit_admin_article_path(@article)
  end

  def edit
    @article = Article.find_by!(slug: params[:id])
    @version = @article.versions.select(&:draft?).max_by(&:number) || @article.live_version || @article.versions.last
    @revision = @version.current_revision
    @chapters = Category.live.order(:parent_id, :position, :name)
  end

  # Manual save (and optionally publish). Autosave goes through RevisionsController.
  def update
    @article = Article.find_by!(slug: params[:id])
    attrs = params.require(:editor).permit(:title, :subtitle, :body, :base_revision_id, :main_category_id, :accessibility, :keywords,
                                           :publish_at, :expire_at, accessor_keys: [])
    notice = "Saved"

    ActiveRecord::Base.transaction do
      @article.update!(main_category_id: attrs[:main_category_id], accessibility: attrs[:accessibility], keyword_list: attrs[:keywords])
      @article.accessor_keys = attrs[:accessor_keys] if attrs.key?(:accessor_keys)
      version = editable_version
      version.save_revision!(body: attrs[:body], author: Current.user, base_revision_id: attrs[:base_revision_id],
                             title: attrs[:title], subtitle: attrs[:subtitle])
      Activity.record!(@article, "update", by: Current.user)
      if attrs.key?(:publish_at) || attrs.key?(:expire_at)
        version.update!(publish_at: Time.zone.parse(attrs[:publish_at].to_s), expire_at: Time.zone.parse(attrs[:expire_at].to_s))
      end
      if params[:publish].present?
        if (reason = version.publish_blocked_for(Current.user))
          notice = "Saved. #{reason}"
        elsif version.scheduled?
          notice = "Scheduled to go live #{version.publish_at.strftime("%-d %b %H:%M %Z")}"
        else
          version.publish!(by: Current.user)
          notice = "Published"
        end
      end
    end
    redirect_to edit_admin_article_path(@article), notice: notice
  rescue ActiveRecord::RecordInvalid => e
    redirect_to edit_admin_article_path(@article), alert: e.record.errors.full_messages.to_sentence
  rescue ArticleVersion::StaleRevision
    redirect_to edit_admin_article_path(@article), alert: "Someone saved a newer copy while you were editing. Your changes weren't saved: reload and reapply them."
  end

  private
    def editable_version
      version = @article.versions.find(params[:editor][:version_id])
      version.draft? ? version : @article.working_version!(author: Current.user)
    end
end
