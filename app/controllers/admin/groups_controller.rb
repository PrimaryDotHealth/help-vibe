# Groups: used for private articles and chapters. Admins only.
class Admin::GroupsController < Admin::BaseController
  before_action { head :forbidden unless Current.user.admin? }
  before_action :set_group, only: %i[edit update destroy]

  def index = @groups = Group.includes(:users).order(:name)
  def new = @group = Group.new

  def create
    @group = Group.new(group_params)
    @group.save ? redirect_to(admin_groups_path, notice: "Group created") : render(:new, status: :unprocessable_entity)
  end

  def edit; end

  def update
    @group.update(group_params) ? redirect_to(admin_groups_path, notice: "Saved") : render(:edit, status: :unprocessable_entity)
  end

  def destroy
    @group.destroy!
    redirect_to admin_groups_path, notice: "Group deleted"
  end

  private
    def set_group = @group = Group.find(params[:id])
    def group_params = params.require(:group).permit(:name, :domain_list, user_ids: [])
end
