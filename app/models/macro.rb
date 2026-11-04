# Saved replies with {{contact.first_name}} / {{contact.name}} / {{agent.first_name}} variables.
class Macro < ApplicationRecord
  belongs_to :team, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  validates :name, :body, presence: true

  def self.for(user) = where(team_id: [ nil ] + user.team_ids).order(:name)

  def render_for(thread, agent)
    vars = {
      "contact.first_name" => thread.contact&.first_name, "contact.name" => thread.contact&.display_name,
      "agent.first_name" => agent.first_name.presence || agent.name.split.first, "agent.name" => agent.name
    }
    body.gsub(/\{\{\s*(contact|agent)\.(first_name|name)\s*\}\}/) { vars["#{Regexp.last_match(1)}.#{Regexp.last_match(2)}"].to_s }
  end
end
