module AdminHelper
  HELPDESK_CONTROLLERS = %w[inbox support_threads tickets macros teams ticket_types ticket_states audit_events].freeze

  # Which product the admin is in: Helpdesk (Intercom side) or Articles
  # (Helpjuice side). They share only people, sign-in and the widget.
  def helpdesk_area?
    return true if HELPDESK_CONTROLLERS.include?(controller_name)
    return action_name == "helpdesk" if controller_name == "install"
    return false if Current.user&.editor?
    Current.user&.agent? || false
  end
end
