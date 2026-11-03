# Content activity log, Helpjuice-shaped (drives webhooks in M3).
class Activity < ApplicationRecord
  belongs_to :owner, class_name: "User", optional: true

  def self.record!(trackable, action, by: nil, automatic: false, extra: {})
    create!(trackable_type: trackable.class.name.underscore, trackable_id: trackable.id,
            owner: by, action: action.to_s, automatic: automatic, extra: extra)
  end
end
