# Development and tests only: a stand-in for our product with the widget embedded.
class DevController < ApplicationController
  allow_unauthenticated_access
  def host = render(layout: false)

  # Iframed articles. `?base=` points the frames at another origin, so tests
  # can check a real cross-site embed (page on localhost, frames on 127.0.0.1).
  def embed
    base = params[:base].to_s
    @base = base.match?(%r{\Ahttps?://[\w.-]+(:\d+)?\z}) ? base : request.base_url
    @article = Article.listed_for(Visibility::Viewer.anonymous).order(:id).first
    render layout: false
  end
end
