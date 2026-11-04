# Old links keep working: anything in slug_redirects (old slugs, imported
# Helpjuice paths) gets a 301 to where the content lives now.
class Reader::RedirectsController < Reader::BaseController
  def show
    path = "/" + params[:path].to_s
    path = "/en_US#{path}" if request.path.start_with?("/en_US/")
    redirect = SlugRedirect.find_by(from_path: path) || SlugRedirect.find_by(from_path: path.delete_suffix("/"))
    raise ActionController::RoutingError, "Not found" unless redirect
    target = redirect.article ? article_path(redirect.article) : chapter_path(redirect.category)
    redirect_to target, status: :moved_permanently
  end
end
