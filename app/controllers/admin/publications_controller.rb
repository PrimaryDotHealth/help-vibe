# Publish the current draft, or take the live version down.
class Admin::PublicationsController < Admin::BaseController
  before_action :require_publisher

  def create
    article = Article.find_by!(slug: params[:article_id])
    version = article.versions.select(&:draft?).max_by(&:number)
    return redirect_to(edit_admin_article_path(article), alert: "Nothing new to publish") unless version&.current_revision
    version.publish!(by: Current.user)
    redirect_to edit_admin_article_path(article), notice: "Published v#{version.number}"
  end

  def destroy
    article = Article.find_by!(slug: params[:article_id])
    article.live_version&.unpublish!(by: Current.user)
    redirect_to edit_admin_article_path(article), notice: "Unpublished"
  end
end
