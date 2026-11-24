# Help center settings (Articles side). Admins only.
class Admin::HelpCenterController < Admin::BaseController
  before_action { head :forbidden unless Current.user.admin? }

  def show
    @contact = Setting.help_center_contact?
    @types = TicketType.for_customers.order(:name)
  end

  def update
    Setting[:help_center_contact] = params[:contact] == "1"
    redirect_to admin_help_center_path, notice: Setting.help_center_contact? ? "Contact support is shown in the help center" : "Contact support is hidden from the help center"
  end
end
