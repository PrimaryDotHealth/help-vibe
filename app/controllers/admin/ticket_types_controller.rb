# S47/S48: ticket types, their fields and states. Admins only.
class Admin::TicketTypesController < Admin::SupportBaseController
  before_action { head :forbidden unless Current.user.admin? }
  before_action :set_type, only: %i[edit update archive]

  def index = @types = TicketType.includes(:fields, :states).order(:archived_at, :category, :name)
  def new = @type = TicketType.new(category: params[:category].presence || "customer")

  def create
    @type = TicketType.new(type_params)
    @type.save ? redirect_to(edit_admin_ticket_type_path(@type), notice: "Ticket type created. Add its fields.") : render(:new, status: :unprocessable_entity)
  end

  def edit
    @type.fields.build(data_type: "string")
  end

  def update
    @type.assign_attributes(type_params.except(:category))
    @type.state_ids = Array(params[:ticket_type][:state_ids]).compact_blank.map(&:to_i) if params[:ticket_type].key?(:state_ids)
    if @type.save
      redirect_to edit_admin_ticket_type_path(@type), notice: "Saved"
    else
      @type.fields.build(data_type: "string") if @type.fields.none?(&:new_record?)
      render :edit, status: :unprocessable_entity
    end
  end

  def archive
    @type.update!(archived_at: @type.archived_at ? nil : Time.current)
    redirect_to admin_ticket_types_path, notice: @type.archived_at ? "Archived" : "Restored"
  end

  private
    def set_type = @type = TicketType.find(params[:id])

    def type_params
      params.require(:ticket_type).permit(:name, :description, :category, :icon, :shareable, :default_team_id,
                                          :description_visible, :description_required,
                                          fields_attributes: %i[id label data_type list_options_text multiline visible_to_contacts
                                                                required_for_contacts required_for_agents required_to_close hidden_on_create archived])
            .tap { |p| p[:fields_attributes]&.each_value { |f| f[:archived_at] = (f.delete(:archived) == "1" ? Time.current : nil) if f.key?(:archived) } }
    end
end
