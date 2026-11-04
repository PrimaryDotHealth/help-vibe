# Support conversations inside the widget (S24-S26).
class Widget::ConversationsController < Widget::BaseController
  include WidgetContact
  include VisitorTracking

  rate_limit to: 10, within: 1.hour, only: :create, by: -> { visitor_hash }, with: -> { head :too_many_requests }
  rate_limit to: 60, within: 10.minutes, only: :reply, by: -> { visitor_hash }, with: -> { head :too_many_requests }
  around_action :with_rls

  def index
    @threads = contact_threads.includes(:parts, :ticket_type, :ticket_state).order(updated_at: :desc).limit(20)
  end

  def new
    @thread = SupportThread.new
  end

  def create
    contact = current_contact
    unless contact
      email = params[:email].to_s.strip
      return redirect_to(new_widget_conversation_path(body: params[:body], page: params[:page]), alert: "Add your email so we can reply") unless email.match?(URI::MailTo::EMAIL_REGEXP)
      contact = Contact.for_email(email, name: params[:name])
    end
    thread = SupportThread.start!(contact: contact, body: params.require(:body), channel: "widget", page_context: params[:page],
                                  search_query: params[:q], client_id: params[:client_id].presence)
    remember_contact!(contact, thread: thread, options: widget_cookie_options)
    redirect_to widget_conversation_path(thread)
  rescue ActiveRecord::RecordInvalid => e
    redirect_to new_widget_conversation_path(page: params[:page]), alert: e.record.errors.full_messages.to_sentence
  end

  def show
    @thread = contact_threads.find_by!(number: params[:number])
    @parts = @thread.parts.where(kind: ThreadPart::CONTACT_VISIBLE).includes(:author_user, :author_contact, files_attachments: :blob)
    AuditEvent.record!(actor: current_contact, action: "view", subject: @thread, request: request)
  end

  def reply
    thread = contact_threads.find_by!(number: params[:number])
    thread.contact_comment!(body: params.require(:body), channel: "widget", client_id: params[:client_id].presence)
    redirect_to widget_conversation_path(thread)
  rescue ActiveRecord::RecordNotUnique
    redirect_to widget_conversation_path(thread) # same client_id twice: already saved
  end

  private
    def with_rls(&) = Rls.with(actor_type: "contact", contact: current_contact, &)
end
