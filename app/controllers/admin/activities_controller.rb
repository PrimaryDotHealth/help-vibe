# Who did what to content and people, newest first (admins).
class Admin::ActivitiesController < Admin::BaseController
  before_action { head :forbidden unless Current.user.admin? }

  def index
    @activities = Activity.includes(:owner).order(id: :desc)
    @activities = @activities.where(trackable_type: params[:type]) if params[:type].present?
    @activities = @activities.where(id: ...params[:before].to_i) if params[:before].present?
    @activities = @activities.limit(100).to_a
    articles = Article.where(id: @activities.select { _1.trackable_type == "article" }.map(&:trackable_id)).includes(:versions).index_by(&:id)
    @labels = @activities.to_h { |a| [ a.id, a.trackable_type == "article" && (art = articles[a.trackable_id]) ? "#{art.code} #{art.versions.max_by(&:number)&.title}" : "#{a.trackable_type} ##{a.trackable_id}" ] }
  end
end
