# Pages other sites may show in an iframe: the widget, single embedded
# articles and the help center. Which sites may do so comes from
# HELPVIBE_FRAME_ANCESTORS (space-separated origins); production defaults to
# none but our own. `?theme=light|dark` pins the colours to match the host
# page, and sticks for the rest of the visit inside the frame.
module Frameable
  extend ActiveSupport::Concern
  THEMES = %w[light dark].freeze
  THEME_COOKIE = :hv_theme

  def self.frame_ancestors = ENV.fetch("HELPVIBE_FRAME_ANCESTORS", Rails.env.production? ? "'self'" : "*")

  included do
    after_action :allow_framing
    helper_method :framed?, :embed_theme
  end

  private
    def allow_framing
      response.headers.delete("X-Frame-Options")
      response.headers["Content-Security-Policy"] = "frame-ancestors #{Frameable.frame_ancestors}"
    end

    # Browsers send Sec-Fetch-Dest on every request (Chrome, Firefox, Safari 16.4+).
    def framed? = request.headers["Sec-Fetch-Dest"] == "iframe"

    def embed_theme
      return @embed_theme if defined?(@embed_theme)
      if THEMES.include?(params[:theme])
        cookies[THEME_COOKIE] = { value: params[:theme], expires: 1.day, httponly: true,
                                  same_site: (Rails.env.test? ? :lax : :none), secure: !Rails.env.test?, partitioned: !Rails.env.test? }
      end
      @embed_theme = THEMES.find { _1 == (params[:theme].presence || cookies[THEME_COOKIE]) }
    end
end
