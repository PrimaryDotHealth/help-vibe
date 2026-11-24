# The help center's Contact page: ask a question or file a request (a
# customer ticket type). Both land in the Helpdesk inbox with channel
# "help_center". Afterwards people follow up on the /t/:token page, and we
# email them that link, because inside an iframe on another site the browser
# may not keep our cookies.
#
# The email is always typed in: we never act as a remembered contact here.
# That makes a forged submission no different from anyone typing the form,
# so the CSRF check can be skipped inside an iframe (where the session
# cookie that carries the token isn't sent).
class Reader::ContactController < Reader::BaseController
  include VisitorTracking
  rate_limit to: 10, within: 1.hour, only: %i[create create_ticket], by: -> { visitor_hash },
             with: -> { redirect_to(contact_path, alert: "That's a lot of messages. Please try again in an hour.") }
  skip_forgery_protection if: -> { framed? }
  before_action { raise ActionController::RoutingError, "Contact is turned off" unless Setting.help_center_contact? }
  before_action :set_type, only: %i[ticket create_ticket]

  def show
    @types = TicketType.for_customers.order(:name)
  end

  def create
    errors = contact_errors
    errors << "Write your question" if params[:body].blank?
    return render_with(errors, :show) if errors.any?
    thread = SupportThread.start!(contact: contact, body: params[:body].to_s.first(20_000), channel: "help_center",
                                  page_context: from_page, search_query: params[:q])
    sent!(thread)
  end

  def ticket; end

  def create_ticket
    values, errors = SupportThread.ticket_fields_from(@type, params[:fields], as: :contact)
    errors = contact_errors + errors
    errors << "Add a short title" if params[:title].blank?
    errors << "Describe the problem" if @type.description_visible && @type.description_required && params[:description].blank?
    return render_with(errors, :ticket) if errors.any?
    thread = SupportThread.open_ticket!(type: @type, title: params[:title], description: (@type.description_visible ? params[:description] : nil),
                                        fields: values, contact: contact, channel: "help_center")
    thread.update!(page_context: from_page) if from_page
    sent!(thread)
  end

  private
    def set_type = @type = TicketType.for_customers.find(params[:type])

    def email = params[:email].to_s.strip
    def contact = @contact ||= Contact.for_email(email, name: params[:name].to_s.strip.presence)

    def contact_errors
      email.match?(URI::MailTo::EMAIL_REGEXP) ? [] : [ "Add your email so we can reply" ]
    end

    # The help center page they came from (an article or search), if any.
    def from_page
      path = params[:from].to_s
      path if path.start_with?("/") && !path.start_with?("//") && path.length <= 500
    end

    def render_with(errors, view)
      @types = TicketType.for_customers.order(:name) if view == :show
      flash.now[:alert] = errors.to_sentence
      render view, status: :unprocessable_entity
    end

    def sent!(thread)
      ThreadMailer.received(thread).deliver_later
      redirect_to contact_thread_path(thread.generate_token_for(:contact_link), sent: 1)
    end
end
