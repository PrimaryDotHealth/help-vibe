# Autosave from the editor. Saving onto a live version transparently starts
# a new draft version; the response tells the editor which version it's on now.
class Admin::RevisionsController < Admin::BaseController
  def create
    from = ArticleVersion.find(params[:version_id])
    version, base = from.article.draft_for_save!(from_version: from, base_revision_id: params[:base_revision_id], author: Current.user)
    revision = version.save_revision!(body: params[:body], author: Current.user, base_revision_id: base,
                                      autosave: params[:autosave].present?, title: params[:title], subtitle: params[:subtitle])
    render json: { revision_id: revision.id, version_id: version.id, version_number: version.number,
                   status: version.article.reload.status_label, saved_at: revision.created_at.strftime("%H:%M") }
  rescue ArticleVersion::StaleRevision
    render json: { error: "stale" }, status: :conflict
  end
end
