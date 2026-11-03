# Everything under /admin needs a signed-in editor (draft writer or above).
class Admin::BaseController < ApplicationController
  layout "admin"
  before_action :require_editor

  private
    def require_editor
      redirect_to root_path, alert: "You don't have access to the admin." unless Current.user&.active? && Current.user.editor?
    end

    def require_publisher
      head :forbidden unless Current.user.can_publish?
    end
end
