# S30/S31: one conversation, its contact, and actions (assign, snooze, close).
class Admin::SupportThreadsController < Admin::SupportBaseController
  before_action :set_thread

  def show
    @parts = @thread.parts.includes(:author_user, :author_contact, files_attachments: :blob)
    @other_threads = @thread.contact ? visible_threads.where(contact: @thread.contact).where.not(id: @thread.id).order(created_at: :desc).limit(5) : []
    @agents = User.active.joins(:team_members).distinct.order(:first_name).to_a | User.active.where(role: %w[superadmin admin]).to_a
    @macros = Macro.for(Current.user)
    @linked = SupportThread.where(id: @thread.links_out.select(:to_thread_id)).or(SupportThread.where(id: @thread.links_in.select(:from_thread_id))).includes(:ticket_type, :ticket_state)
    @thread.mark_read!(Current.user)
    Notification.unread.where(user: Current.user, thread: @thread).update_all(read_at: Time.current)
    AuditEvent.record!(actor: Current.user, action: "view", subject: @thread, request: request)
  end

  def update
    case params[:do]
    when "assign"
      user = params[:user_id].presence && User.active.find(params[:user_id])
      team = params[:team_id].presence && Team.find(params[:team_id])
      @thread.assign!(by: Current.user, user: user, team: team)
      AuditEvent.record!(actor: Current.user, action: "assign", subject: @thread, request: request, detail: { user_id: user&.id, team_id: team&.id })
    when "take" then @thread.assign!(by: Current.user, user: Current.user)
    when "close" then @thread.close!(by: Current.user)
    when "reopen" then @thread.reopen!(by: Current.user)
    when "snooze" then @thread.snooze!(by: Current.user, until_time: snooze_until)
    when "priority" then @thread.update!(priority: params[:priority]) if SupportThread::PRIORITIES.include?(params[:priority])
    when "ticket_state" then @thread.change_ticket_state!(TicketState.find(params[:ticket_state_id]), by: Current.user)
    when "fields"
      errors = @thread.update_ticket_fields!(params[:fields], by: Current.user)
      return redirect_to(admin_support_thread_path(@thread), alert: errors.to_sentence) if errors.any?
    when "convert"
      type = TicketType.for_customers.find(params[:ticket_type_id])
      @thread.convert_to_ticket!(type: type, title: params[:title], by: Current.user)
    end
    redirect_to(params[:do] == "close" ? admin_inbox_path : admin_support_thread_path(@thread))
  rescue SupportThread::TicketError => e
    redirect_to admin_support_thread_path(@thread), alert: e.message
  end

  private
    def set_thread = @thread = visible_threads.find_by!(number: params[:number])

    def snooze_until
      case params[:until]
      when "1h" then 1.hour.from_now
      when "tomorrow" then Time.zone.tomorrow.to_time.change(hour: 9)
      when "next_week" then Time.zone.today.next_week.to_time.change(hour: 9)
      else raise ActionController::BadRequest, "Pick a snooze time"
      end
    end
end
