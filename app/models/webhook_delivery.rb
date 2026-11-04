class WebhookDelivery < ApplicationRecord
  RETRY_AFTER = [ 1.minute, 5.minutes, 30.minutes, 2.hours, 12.hours ].freeze

  belongs_to :webhook
  belongs_to :activity

  # Helpjuice's payload: event, activity_fields, and activity (as a string).
  def payload
    fields = {
      id: activity.id, action: activity.action, trackable_type: activity.trackable_type.camelize, trackable_id: activity.trackable_id,
      owner_type: activity.owner_id ? "User" : nil, owner_id: activity.owner_id, created_at: activity.created_at,
      extra: activity.extra, automatic: activity.automatic
    }
    { event: webhook.event, activity_fields: fields, activity: fields.to_json }.to_json
  end
end
