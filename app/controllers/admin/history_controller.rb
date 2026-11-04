# S13: revision history for one version, a word-level comparison, and restore.
class Admin::HistoryController < Admin::BaseController
  before_action :set_article

  def show
    @versions = @article.versions.reverse
    @version = params[:version_id] ? @article.versions.find(params[:version_id]) : (@article.versions.select(&:draft?).max_by(&:number) || @article.live_version || @versions.first)
    @revisions = @version.revisions.includes(:author).order(id: :desc).to_a
    @current = @version.current_revision
    @show_autosaves = params[:autosaves].present?
    @listed = @show_autosaves ? @revisions : @revisions.select { !_1.autosave || _1 == @current }
    @hidden_autosaves = @revisions.size - @listed.size

    @compare = if params[:against] == "live" then @article.live_version&.current_revision
    elsif params[:revision_id] then @version.revisions.find(params[:revision_id])
    else @revisions.find { _1 != @current }
    end
    @diff = Helpvibe::WordDiff.call(@compare&.body_text, @current&.body_text) if @compare && @current
  end

  def restore
    revision = Revision.joins(:version).where(article_versions: { article_id: @article.id }).find(params[:revision_id])
    draft = @article.working_version!(author: Current.user)
    draft.save_revision!(body: revision.body_html, author: Current.user, base_revision_id: draft.current_revision_id)
    redirect_to edit_admin_article_path(@article), notice: "Restored the #{revision.created_at.strftime("%-d %b %H:%M")} copy into v#{draft.number}. Publish when ready."
  end

  private
    def set_article = @article = Article.find_by!(slug: params[:article_id])
end
