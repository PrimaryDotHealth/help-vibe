# /admin: Helpdesk first for anyone with the inbox, Articles otherwise.
class Admin::HomeController < Admin::BaseController
  skip_before_action :require_editor

  def show
    return redirect_to(admin_inbox_path) if Current.user&.agent?
    return redirect_to(admin_articles_path) if Current.user&.editor?
    redirect_to root_path, alert: "You don't have access to the admin."
  end
end
