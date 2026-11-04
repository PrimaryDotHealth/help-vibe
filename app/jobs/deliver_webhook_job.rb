# POSTs one delivery. On failure, schedules the next try (1m, 5m, 30m, 2h, 12h)
# and finally marks it dead. Only 2xx counts as delivered.
class DeliverWebhookJob < ApplicationJob
  queue_as :default

  def perform(delivery_id)
    delivery = WebhookDelivery.find_by(id: delivery_id) or return
    return if delivery.status.in?(%w[delivered dead])
    webhook = delivery.webhook
    return delivery.update!(status: "dead", error: "webhook disabled") unless webhook.enabled?

    body = delivery.payload
    uri = URI(webhook.url)
    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json", "User-Agent" => "helpvibe-webhooks",
                                       "X-Helpvibe-Event" => webhook.event, "X-Helpvibe-Delivery" => delivery.id.to_s,
                                       "X-Helpvibe-Signature" => webhook.sign(body))
    request.body = body
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 10) { _1.request(request) }
    code = response.code.to_i
    webhook.update_column(:last_response_code, code)
    if code.between?(200, 299)
      delivery.update!(status: "delivered", response_code: code, delivered_at: Time.current, attempt: delivery.attempt + 1, error: nil)
    else
      retry_later(delivery, code: code, error: "HTTP #{code}")
    end
  rescue StandardError => e
    retry_later(delivery, error: e.message.first(500)) if delivery
  end

  private
    def retry_later(delivery, code: nil, error:)
      attempt = delivery.attempt + 1
      wait = WebhookDelivery::RETRY_AFTER[attempt - 1]
      if wait
        delivery.update!(status: "failed", attempt: attempt, response_code: code, error: error, next_attempt_at: wait.from_now)
        self.class.set(wait: wait).perform_later(delivery.id)
      else
        delivery.update!(status: "dead", attempt: attempt, response_code: code, error: error)
      end
    end
end
