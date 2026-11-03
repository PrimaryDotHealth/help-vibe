# Development only: a stand-in for our product with the widget embedded.
class DevController < ApplicationController
  allow_unauthenticated_access
  def host = render(layout: false)
end
