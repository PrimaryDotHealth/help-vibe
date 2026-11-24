# /t/:token: the link in our emails. Lets a contact read and reply without
# signing in, and remembers this browser for that conversation.
class ContactThreadsController < ApplicationController
  include WidgetContact
  include Frameable
  allow_unauthenticated_access
  # The token in the address is what grants access, not a cookie, so inside
  # an iframe (where the session cookie with the CSRF token isn't sent) a
  # reply doesn't need the CSRF check.
  skip_forgery_protection if: -> { framed? }
  before_action :set_thread

  def show
    @parts = @thread.parts.where(kind: ThreadPart::CONTACT_VISIBLE).includes(:author_user, :author_contact)
    AuditEvent.record!(actor: @thread.contact, action: "view", subject: @thread, request: request, detail: { via: "email link" })
  end

  def reply
    channel = @thread.channel == "help_center" ? "help_center" : "widget"
    @thread.contact_comment!(body: params.require(:body), channel: channel, client_id: params[:client_id].presence)
    redirect_to contact_thread_path(params[:token])
  rescue ActiveRecord::RecordNotUnique
    redirect_to contact_thread_path(params[:token])
  end

  private
    def set_thread
      @thread = SupportThread.find_by_token_for(:contact_link, params[:token])
      raise ActiveRecord::RecordNotFound unless @thread&.contact && @thread.shared_with_contact?
      remember_contact!(@thread.contact, thread: @thread, options: { same_site: :lax })
    end
end
