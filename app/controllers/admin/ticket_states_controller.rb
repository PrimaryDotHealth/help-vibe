# S49: ticket states. Labels can change; states are archived, never deleted.
class Admin::TicketStatesController < Admin::SupportBaseController
  before_action { head :forbidden unless Current.user.admin? }

  def index
    TicketState.ensure_defaults!
    @states = TicketState.in_order.to_a
    @state = TicketState.new(category: "in_progress")
  end

  def create
    state = TicketState.new(params.require(:ticket_state).permit(:category, :internal_label, :external_label, :notify_customer))
    state.save ? redirect_to(admin_ticket_states_path, notice: "State added. Add it to ticket types to use it.") : redirect_to(admin_ticket_states_path, alert: state.errors.full_messages.to_sentence)
  end

  def update
    state = TicketState.find(params[:id])
    attrs = params.require(:ticket_state).permit(:internal_label, :external_label, :notify_customer)
    attrs[:archived_at] = params[:ticket_state][:archived] == "1" ? (state.archived_at || Time.current) : nil if params[:ticket_state].key?(:archived)
    state.update(attrs) ? redirect_to(admin_ticket_states_path, notice: "Saved") : redirect_to(admin_ticket_states_path, alert: state.errors.full_messages.to_sentence)
  end
end
