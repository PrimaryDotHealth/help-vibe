# Pages shown inside the widget's iframe in our app. Readers are anonymous
# unless our app passed a signed token (see Widget::SessionsController).
class Widget::BaseController < ApplicationController
  WIDGET_COOKIE = :hv_widget

  include WidgetContact

  allow_unauthenticated_access
  layout "widget"
  after_action :allow_framing
  helper_method :widget_identity, :viewer, :current_contact

  private
    def widget_identity
      return @widget_identity if defined?(@widget_identity)
      @widget_identity = WidgetIdentity.from_cookie(cookies.encrypted[WIDGET_COOKIE])
    end

    def viewer = widget_identity&.viewer || Visibility::Viewer.anonymous

    def widget_cookie_options
      { same_site: (Rails.env.test? ? :lax : :none), secure: !Rails.env.test?, partitioned: !Rails.env.test?, httponly: true }
    end

    def widget_cookie(value) = widget_cookie_options.merge(value: value, expires: 8.hours)

    def allow_framing
      response.headers.delete("X-Frame-Options")
      ancestors = ENV.fetch("HELPVIBE_FRAME_ANCESTORS", Rails.env.production? ? "'self'" : "*")
      response.headers["Content-Security-Policy"] = "frame-ancestors #{ancestors}"
    end
end
