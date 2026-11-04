# Editor comments on a version. Internal: readers never see them.
class Admin::CommentsController < Admin::BaseController
  def create
    version = ArticleVersion.find(params[:version_id])
    quote = params[:quote].to_s.squish.first(300).presence
    version.comments.create!(author: Current.user, body: params.require(:body), parent_id: params[:parent_id].presence,
                             anchor: quote ? { "quote" => quote } : nil)
    redirect_to edit_admin_article_path(version.article, anchor: "comments")
  rescue ActionController::ParameterMissing, ActiveRecord::RecordInvalid
    redirect_to edit_admin_article_path(version.article, anchor: "comments"), alert: "Write something first"
  end

  def update
    comment = Comment.find(params[:id])
    comment.update!(resolved_at: params[:resolved] == "1" ? Time.current : nil)
    redirect_to edit_admin_article_path(comment.version.article, anchor: "comments")
  end
end
