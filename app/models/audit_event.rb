# Append-only access log of patient data (S42). The database refuses updates
# and early deletes (trigger), kept 6 years.
class AuditEvent < ApplicationRecord
  def readonly? = persisted?

  def self.record!(actor:, action:, subject:, request: nil, detail: {})
    type, id, label =
      case actor
      when User then [ "user", actor.id, actor.email_address ]
      when Contact then [ "contact", actor.id, actor.display_name ]
      when ApiKey then [ "api_key", actor.id, actor.name ]
      else [ "system", nil, "system" ]
      end
    create!(actor_type: type, actor_id: id, actor_label: label, action: action,
            subject_type: subject.is_a?(SupportThread) ? "thread" : subject.class.name.underscore, subject_id: subject.id,
            ip: request&.remote_ip, user_agent: request&.user_agent&.first(300), detail: detail)
  end
end
