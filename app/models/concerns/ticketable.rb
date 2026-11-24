# Ticket behaviour for SupportThread (replica/recon.md Part 3).
module Ticketable
  extend ActiveSupport::Concern

  class TicketError < StandardError; end

  included do
    belongs_to :ticket_type, optional: true
    belongs_to :ticket_state, optional: true
    belongs_to :created_by, class_name: "User", optional: true
    has_many :links_out, class_name: "ThreadLink", foreign_key: :from_thread_id, dependent: :delete_all
    has_many :links_in, class_name: "ThreadLink", foreign_key: :to_thread_id, dependent: :delete_all

    scope :tickets, -> { where(kind: "ticket") }
    scope :conversations, -> { where(kind: "conversation") }
  end

  class_methods do
    # Form input -> [values, errors].
    #   as: :contact     fields visible to contacts; "required for customers" enforced
    #   as: :agent       the agent creation form (minus hidden fields); "required for agents" enforced
    #   as: :agent_edit  every live field on an existing ticket; nothing forced
    def ticket_fields_from(type, raw, as:)
      # Only known field keys are read, and every value is cast by its format.
      raw = (raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h).stringify_keys
      values, errors = {}, []
      fields = type.live_fields.select do |f|
        case as
        when :contact then f.visible_to_contacts
        when :agent then !f.hidden_on_create
        else true
        end
      end
      fields.each do |f|
        value, error = f.cast(raw[f.key])
        errors << "#{f.label} #{error}" if error
        required = { contact: f.required_for_contacts, agent: f.required_for_agents }.fetch(as, false)
        errors << "#{f.label} is required" if required && value.nil? && error.nil?
        values[f.key] = value unless value.nil?
      end
      [ values, errors ]
    end

    def open_ticket!(type:, title:, description: "", fields: {}, contact: nil, by: nil, channel: "internal", link_from: nil, team: nil)
      raise TicketError, "Ticket type is archived" if type.archived_at
      raise TicketError, "A title is required" if title.blank?
      raise TicketError, "#{type.name} needs a description" if description.blank? && type.description_required && by.nil?
      transaction do
        ticket = create!(kind: "ticket", ticket_type: type, ticket_state: type.first_state, contact: contact || link_from&.contact, created_by: by,
                         channel: channel, title: title.to_s.squish.first(200),
                         ticket_attributes: fields.merge("description" => description.to_s.strip.presence).compact,
                         is_shared: type.shared_with_customer?, waiting_since: by ? nil : Time.current,
                         assignee_team: team || type.default_team, assignee_user: (by if type.category != "customer" && team.nil?))
        if link_from
          ThreadLink.create!(from_thread: link_from, to_thread: ticket, kind: type.category == "tracker" ? "tracker" : "handoff", created_by: by)
          link_from.parts.create!(author_type: by ? "user" : "system", author_user: by, kind: "link", channel: by ? "admin" : "system",
                                  event: { ticket_number: ticket.number, ticket_type: type.name })
        end
        ticket
      end.tap do |ticket|
        # Tell the customer when the team opens a request on their behalf.
        if by && ticket.is_shared && ticket.contact&.email.present?
          ThreadMailer.ticket_opened(ticket).deliver_later
        end
      end
    end
  end

  def ticket? = kind == "ticket"

  def created_by_label
    created_by&.name || (%w[widget help_center].include?(channel) ? contact&.display_name || "the customer" : "the team")
  end
  def description = ticket_attributes.to_h["description"]
  def shared_with_contact? = !ticket? || is_shared

  # The conversation itself becomes a customer ticket; history is kept.
  def convert_to_ticket!(type:, title:, fields: {}, by:)
    raise TicketError, "Only customer ticket types can be converted into" unless type.customer?
    raise TicketError, "Already a ticket" if ticket?
    transaction do
      update!(kind: "ticket", ticket_type: type, ticket_state: type.first_state, ticket_attributes: fields,
              is_shared: true, title: title.presence || self.title)
      parts.create!(author_type: "user", author_user: by, kind: "ticket_state_change", channel: "admin",
                    event: { converted: true, type: type.name, internal: ticket_state.internal_label, external: ticket_state.external_label })
    end
  end

  def missing_to_close
    ticket_type.live_fields.select { _1.required_to_close && ticket_attributes.to_h[_1.key].nil? }
  end

  def change_ticket_state!(state, by:)
    raise TicketError, "Not a ticket" unless ticket?
    raise TicketError, "#{state.internal_label} isn't a state of #{ticket_type.name}" unless ticket_type.states.include?(state)
    if state.resolved? && (missing = missing_to_close).any?
      raise TicketError, "Fill in #{missing.map(&:label).to_sentence} before resolving"
    end
    return if state == ticket_state
    transaction do
      update!(ticket_state: state, state: state.resolved? ? "closed" : "open", closed_at: (Time.current if state.resolved?),
              snoozed_until: nil, waiting_since: (state.category == "waiting_on_customer" || state.resolved? ? nil : waiting_since))
      parts.create!(author_type: by ? "user" : "system", author_user: by, kind: "ticket_state_change", channel: by ? "admin" : "system",
                    event: { internal: state.internal_label, external: state.external_label })
    end
    ThreadMailer.ticket_state_changed(self).deliver_later if is_shared && state.notify_customer && contact&.email.present?
  end

  # Agents edit fields after creation (customers can't). Returns errors.
  def update_ticket_fields!(raw, by:)
    values, errors = self.class.ticket_fields_from(ticket_type, raw, as: :agent_edit)
    return errors if errors.any?
    changed = values.reject { |k, v| ticket_attributes.to_h[k] == v }
    return [] if changed.empty?
    transaction do
      update!(ticket_attributes: ticket_attributes.to_h.merge(values))
      parts.create!(author_type: "user", author_user: by, kind: "attribute_change", channel: "admin", event: { changed: changed.keys })
    end
    []
  end

  # A contact replying on a resolved ticket moves it back to in progress.
  def reopen_ticket_on_reply!
    return unless ticket? && ticket_state&.resolved?
    back = ticket_type.states.live.in_order.find { _1.category == "in_progress" } || ticket_type.first_state
    update!(ticket_state: back)
    parts.create!(author_type: "system", kind: "ticket_state_change", channel: "system",
                  event: { internal: back.internal_label, external: back.external_label, reopened: true })
  end
end
