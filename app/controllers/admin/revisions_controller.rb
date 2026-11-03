# Autosave from the editor. Saving onto a live version transparently starts
# a new draft version; the response tells the editor which version it's on now.
class Admin::RevisionsController < Admin::BaseController
  def create
    version = ArticleVersion.find(params[:version_id])
    base = params[:base_revision_id]
    unless version.draft?
      version = version.article.working_version!(author: Current.user)
      base = version.current_revision_id
    end
    revision = version.save_revision!(body: params[:body], author: Current.user, base_revision_id: base,
                                      autosave: params[:autosave].present?, title: params[:title], subtitle: params[:subtitle])
    render json: { revision_id: revision.id, version_id: version.id, version_number: version.number,
                   status: version.article.reload.status_label, saved_at: revision.created_at.strftime("%H:%M") }
  rescue ArticleVersion::StaleRevision
    render json: { error: "stale" }, status: :conflict
  end
end
