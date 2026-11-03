# Pages shown inside the widget's iframe in our app. M1: public articles only;
# the signed token from our app (internal articles for staff) arrives in M2.
class Widget::BaseController < ApplicationController
  allow_unauthenticated_access
  layout "widget"
  after_action :allow_framing

  private
    def allow_framing
      response.headers.delete("X-Frame-Options")
      ancestors = ENV.fetch("HELPVIBE_FRAME_ANCESTORS", Rails.env.production? ? "'self'" : "*")
      response.headers["Content-Security-Policy"] = "frame-ancestors #{ancestors}"
    end
end
