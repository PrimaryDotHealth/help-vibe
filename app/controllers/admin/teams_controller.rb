# Support teams (admins). Being in a team is what makes someone an agent.
class Admin::TeamsController < Admin::BaseController
  before_action { head :forbidden unless Current.user.admin? }
  before_action :set_team, only: %i[edit update destroy]

  def index = @teams = Team.includes(:users).order(:name)
  def new = @team = Team.new

  def create
    @team = Team.new(team_params)
    @team.save ? redirect_to(admin_teams_path, notice: "Team created") : render(:new, status: :unprocessable_entity)
  end

  def edit; end

  def update
    @team.update(team_params) ? redirect_to(admin_teams_path, notice: "Saved") : render(:edit, status: :unprocessable_entity)
  end

  def destroy
    @team.destroy!
    redirect_to admin_teams_path, notice: "Team deleted"
  end

  private
    def set_team = @team = Team.find(params[:id])
    def team_params = params.require(:team).permit(:name, user_ids: [])
end
