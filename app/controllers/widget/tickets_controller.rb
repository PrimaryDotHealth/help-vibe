# S50: customers submit a ticket from the widget (customer ticket types only).
class Widget::TicketsController < Widget::BaseController
  include VisitorTracking
  rate_limit to: 10, within: 1.hour, only: :create, by: -> { visitor_hash }, with: -> { head :too_many_requests }

  def new
    @type = TicketType.for_customers.find(params[:type])
  end

  def create
    @type = TicketType.for_customers.find(params[:type])
    values, errors = SupportThread.ticket_fields_from(@type, params[:fields], as: :contact)
    errors << "Add a short title" if params[:title].blank?
    errors << "Describe the problem" if @type.description_visible && @type.description_required && params[:description].blank?
    contact = current_contact
    if contact.nil?
      email = params[:email].to_s.strip
      email.match?(URI::MailTo::EMAIL_REGEXP) ? (contact = Contact.for_email(email, name: params[:name])) : errors << "Add your email so we can reply"
    end
    if errors.any?
      flash.now[:alert] = errors.to_sentence
      return render(:new, status: :unprocessable_entity)
    end
    ticket = SupportThread.open_ticket!(type: @type, title: params[:title], description: (@type.description_visible ? params[:description] : nil),
                                        fields: values, contact: contact, channel: "widget")
    ticket.update!(page_context: params[:page].presence)
    remember_contact!(contact, thread: ticket, options: widget_cookie_options)
    redirect_to widget_conversation_path(ticket)
  end
end
