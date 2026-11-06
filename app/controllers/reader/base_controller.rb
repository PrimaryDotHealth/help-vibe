# Public help center. Anyone can read; signed-in staff also see internal articles.
class Reader::BaseController < ApplicationController
  include Frameable
  allow_unauthenticated_access
  before_action :resume_session
  helper_method :viewer

  private
    def viewer = Current.user
end
