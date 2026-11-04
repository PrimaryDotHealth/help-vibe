# Support desk pages: agents only (people in a support team, or admins), with
# the row-level-security context set for the request.
class Admin::SupportBaseController < Admin::BaseController
  skip_before_action :require_editor
  before_action :require_agent
  around_action :with_rls

  private
    def require_agent
      redirect_to root_path, alert: "The inbox is for support agents" unless Current.user&.agent?
    end

    def with_rls(&) = Rls.with(actor_type: "user", user: Current.user, &)
    def visible_threads = SupportThread.visible_to_agent(Current.user)
end
