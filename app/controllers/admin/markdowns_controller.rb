# "Paste Markdown": converts Markdown to the editor's HTML as a new revision
# on the working draft (the Markdown-mode feature, without a second editor).
class Admin::MarkdownsController < Admin::BaseController
  def create
    version = ArticleVersion.find(params[:version_id])
    article = version.article
    markdown = params.require(:markdown).to_s
    html = Commonmarker.to_html(markdown, options: { render: { unsafe: false }, extension: { table: true, strikethrough: true, autolink: true, header_ids: nil } })
    draft = version.draft? ? version : article.working_version!(author: Current.user)
    draft.save_revision!(body: html, author: Current.user, base_revision_id: draft.current_revision_id)
    draft.current_revision.update!(markdown_source: markdown, body_format: "markdown")
    redirect_to edit_admin_article_path(article), notice: "Markdown converted into the draft"
  rescue ActionController::ParameterMissing
    redirect_to edit_admin_article_path(version.article), alert: "Paste some Markdown first"
  end
end
