# One activity -> one delivery per subscribed webhook (unique per pair).
class FanOutActivityJob < ApplicationJob
  queue_as :default

  def perform(activity_id)
    activity = Activity.find_by(id: activity_id) or return
    event = activity.webhook_event or return
    Webhook.enabled.where(event: event).find_each do |webhook|
      delivery = WebhookDelivery.create_or_find_by!(webhook: webhook, activity: activity)
      DeliverWebhookJob.perform_later(delivery.id) if delivery.previously_new_record?
    end
  end
end
