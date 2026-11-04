# S44/S45: all tickets, and a new ticket from scratch. Ticket pages are the
# thread page (Admin::SupportThreadsController).
class Admin::TicketsController < Admin::SupportBaseController
  def index
    @types = TicketType.live.order(:name)
    @states = TicketState.live.in_order
    scope = visible_threads.tickets.includes(:contact, :ticket_type, :ticket_state, :assignee_user, :assignee_team)
    scope = scope.where(ticket_type_id: params[:type]) if params[:type].present?
    scope = scope.where(ticket_state_id: params[:state]) if params[:state].present?
    scope = scope.joins(:ticket_type).where(ticket_types: { category: params[:category] }) if TicketType::CATEGORIES.include?(params[:category])
    scope = scope.where(assignee_user: Current.user) if params[:mine].present?
    scope = scope.where.not(state: "closed") unless params[:state].present? || params[:resolved].present?
    @tickets = scope.order(updated_at: :desc).limit(200)
  end

  def new
    @types = TicketType.live.order(:category, :name)
    @type = TicketType.live.find_by(id: params[:ticket_type_id] || params[:type]) || @types.first
    @from = visible_threads.find_by(number: params[:from]) if params[:from]
  end

  def create
    type = TicketType.live.find(params.require(:ticket_type_id))
    from = visible_threads.find_by(number: params[:from]) if params[:from].present?
    values, errors = SupportThread.ticket_fields_from(type, params[:fields], as: :agent)
    contact = from&.contact || (Contact.for_email(params[:email]) if params[:email].present?)
    errors << "Customer tickets need the customer's email" if type.customer? && contact.nil?
    if errors.any?
      flash.now[:alert] = errors.to_sentence
      @types = TicketType.live.order(:category, :name)
      @type, @from = type, from
      return render(:new, status: :unprocessable_entity)
    end

    ticket = SupportThread.open_ticket!(type: type, title: params[:title], description: params[:description], fields: values,
                                        contact: contact, by: Current.user, channel: "internal", link_from: from,
                                        team: params[:team_id].presence && Team.find(params[:team_id]))
    redirect_to admin_support_thread_path(ticket), notice: "Ticket ##{ticket.number} created"
  rescue SupportThread::TicketError, ActiveRecord::RecordInvalid => e
    redirect_to new_admin_ticket_path(type: params[:ticket_type_id], from: params[:from]), alert: e.message
  end
end
