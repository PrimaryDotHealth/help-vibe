module ApplicationCable
  # Staff connect with their session cookie; widget contacts with the widget's
  # contact cookie. Turbo's signed stream names (only rendered for people
  # allowed to see a thread) decide what each connection can subscribe to.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_contact_id

    def connect
      set_current_user || set_current_contact || reject_unauthorized_connection
    end

    private
      def set_current_user
        if (session = Session.find_by(id: cookies.signed[:session_id])) && session.user.active?
          self.current_user = session.user
        end
      end

      def set_current_contact
        id = (cookies.encrypted[WidgetContact::CONTACT_COOKIE] || {})["contact_id"]
        self.current_contact_id = id if id
      end
  end
end
