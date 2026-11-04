# Saved replies (S35). Agents manage their team's and shared ones.
class Admin::MacrosController < Admin::SupportBaseController
  before_action :set_macro, only: %i[edit update destroy]

  def index = @macros = Macro.for(Current.user).includes(:team, :created_by)
  def new = @macro = Macro.new

  def create
    @macro = Macro.new(macro_params.merge(created_by: Current.user))
    @macro.save ? redirect_to(admin_macros_path, notice: "Saved") : render(:new, status: :unprocessable_entity)
  end

  def edit; end

  def update
    @macro.update(macro_params) ? redirect_to(admin_macros_path, notice: "Saved") : render(:edit, status: :unprocessable_entity)
  end

  def destroy
    @macro.destroy!
    redirect_to admin_macros_path, notice: "Deleted"
  end

  private
    def set_macro = @macro = Macro.for(Current.user).find(params[:id])

    def macro_params
      permitted = params.require(:macro).permit(:name, :body, :team_id)
      permitted[:team_id] = nil if permitted[:team_id].present? && !Current.user.admin? && !Current.user.team_ids.include?(permitted[:team_id].to_i)
      permitted
    end
end
