# Public help center. Anyone can read; signed-in staff also see internal articles.
class Reader::BaseController < ApplicationController
  include Frameable
  include CollectionFilter
  allow_unauthenticated_access
  before_action :resume_session
  helper_method :viewer

  private
    def viewer = @viewer ||= within_collections(Visibility.viewer(Current.user))
end
