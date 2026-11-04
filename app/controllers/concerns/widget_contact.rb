# Who the contact is inside the widget (or on an emailed link).
#   * from our app's signed token: a verified contact, sees all their threads
#   * from an email typed into the widget: unverified, sees only the threads
#     this browser started or opened from an email link (thread ids in the cookie)
module WidgetContact
  CONTACT_COOKIE = :hv_contact

  private
    def current_contact
      return @current_contact if defined?(@current_contact)
      @current_contact =
        if (identity = widget_identity_if_any) && identity.sub.present?
          Contact.from_identity(identity)
        elsif (id = contact_cookie["contact_id"])
          Contact.find_by(id: id)
        end
    end

    def contact_cookie = (cookies.encrypted[CONTACT_COOKIE] || {}).with_indifferent_access

    def contact_verified? = current_contact&.external_id.present? && widget_identity_if_any&.sub.present?

    # The widget token's identity (widget pages only; `try` would skip it as private).
    def widget_identity_if_any = respond_to?(:widget_identity, true) ? widget_identity : nil

    def contact_threads
      return SupportThread.none unless current_contact
      scope = current_contact.threads
      contact_verified? ? scope : scope.where(id: Array(contact_cookie["thread_ids"]))
    end

    def remember_contact!(contact, thread: nil, options: {})
      ids = contact_cookie["contact_id"] == contact.id ? Array(contact_cookie["thread_ids"]) : []
      ids = (ids + [ thread&.id ]).compact.uniq.last(50)
      cookies.encrypted[CONTACT_COOKIE] = { value: { contact_id: contact.id, thread_ids: ids }, expires: 30.days, httponly: true, **options }
      @current_contact = contact
    end
end
