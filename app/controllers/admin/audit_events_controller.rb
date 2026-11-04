# S42: the access log. Superadmins and people with the compliance permission.
class Admin::AuditEventsController < Admin::BaseController
  skip_before_action :require_editor
  before_action { head :forbidden unless Current.user&.superadmin? || Current.user&.permissions&.include?("compliance") }

  def index
    @events = AuditEvent.order(id: :desc)
    @events = @events.where(subject_type: "thread", subject_id: SupportThread.where(number: params[:thread]).select(:id)) if params[:thread].present?
    @events = @events.where(actor_type: "user", actor_id: User.where(email_address: params[:actor].to_s.downcase).select(:id)) if params[:actor].present?
    @events = @events.where(id: ...params[:before].to_i) if params[:before].present?
    @events = @events.limit(200).to_a
    @thread_numbers = SupportThread.where(id: @events.select { _1.subject_type == "thread" }.map(&:subject_id)).pluck(:id, :number).to_h
  end
end
