# Everything under /admin needs a signed-in editor (draft writer or above).
class Admin::BaseController < ApplicationController
  layout "admin"
  before_action :require_editor

  private
    def require_editor
      return if Current.user&.active? && Current.user.editor?
      return redirect_to(admin_inbox_path) if Current.user&.agent?
      redirect_to root_path, alert: "You don't have access to the admin."
    end

    def require_publisher
      head :forbidden unless Current.user.can_publish?
    end
end
