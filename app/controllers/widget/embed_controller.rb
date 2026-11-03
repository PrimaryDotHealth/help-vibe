# GET /embed.js: the loader our app includes with one script tag.
class Widget::EmbedController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection

  def show
    expires_in 5.minutes, public: true
    render formats: :js, content_type: "text/javascript"
  end
end
