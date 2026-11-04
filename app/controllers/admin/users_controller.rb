# People (S17): invite, change role, deactivate. Admins only.
class Admin::UsersController < Admin::BaseController
  before_action :require_admin
  before_action :set_user, only: %i[edit update]

  def index
    @users = User.includes(:groups).order(active: :desc, role: :asc, email_address: :asc)
  end

  def new
    @user = User.new(role: "draft_writer")
  end

  def create
    @user = User.new(user_params.merge(password: SecureRandom.base58(24), role: requested_role || "draft_writer"))
    if @user.save
      Group.auto_join!(@user)
      UsersMailer.invitation(@user).deliver_later
      redirect_to admin_users_path, notice: "Invitation sent to #{@user.email_address}"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    attrs = user_params
    role = requested_role || @user.role
    if @user.superadmin? && !Current.user.superadmin?
      return redirect_to(admin_users_path, alert: "Only superadmins can change a superadmin")
    end
    if @user == Current.user && (role != @user.role || attrs[:active] == "0")
      return redirect_to(edit_admin_user_path(@user), alert: "You can't change your own role or deactivate yourself")
    end
    if @user.superadmin? && (role != "superadmin" || attrs[:active] == "0") && User.active.where(role: "superadmin").count == 1
      return redirect_to(edit_admin_user_path(@user), alert: "There must be at least one active superadmin")
    end
    if @user.update(attrs.merge(role: role))
      @user.sessions.destroy_all unless @user.active?
      redirect_to admin_users_path, notice: "Saved"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def require_admin = (head :forbidden unless Current.user.admin?)
    def set_user = @user = User.find(params[:id])

    def user_params
      permitted = params.require(:user).permit(:first_name, :last_name, :active, group_ids: [])
      permitted[:email_address] = params[:user][:email_address] if action_name == "create"
      permitted
    end

    # Roles are assigned explicitly, never mass-assigned: only real roles, and
    # only superadmins can hand out superadmin.
    def requested_role
      role = params.dig(:user, :role).to_s
      return nil unless User::ROLES.include?(role)
      return nil if role == "superadmin" && !Current.user.superadmin?
      role
    end
end
