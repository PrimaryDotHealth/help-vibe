# Pages shown inside the widget's iframe in our app. Readers are anonymous
# unless our app passed a signed token (see Widget::SessionsController).
class Widget::BaseController < ApplicationController
  WIDGET_COOKIE = :hv_widget

  include WidgetContact
  include Frameable
  include CollectionFilter

  allow_unauthenticated_access
  layout "widget"
  helper_method :widget_identity, :viewer, :current_contact

  private
    def widget_identity
      return @widget_identity if defined?(@widget_identity)
      @widget_identity = WidgetIdentity.from_cookie(cookies.encrypted[WIDGET_COOKIE])
    end

    def viewer = @viewer ||= within_collections(widget_identity&.viewer || Visibility::Viewer.anonymous)

    def widget_cookie_options
      { same_site: (Rails.env.test? ? :lax : :none), secure: !Rails.env.test?, partitioned: !Rails.env.test?, httponly: true }
    end

    def widget_cookie(value) = widget_cookie_options.merge(value: value, expires: 8.hours)
end
