require "test_helper"

class WebhookTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # Captures the request instead of going to the network.
  class FakeHTTP
    Response = Struct.new(:code)
    class << self
      attr_accessor :code, :last_request, :raise_error
    end

    def self.start(*_, **_)
      raise raise_error if raise_error
      yield new
    end

    def request(req)
      self.class.last_request = req
      Response.new(self.class.code.to_s)
    end
  end

  setup do
    FakeHTTP.code = 200
    FakeHTTP.raise_error = nil
    @hook = Webhook.create!(url: "https://example.com/hooks", event: "question_publish", created_by: users(:one))
  end

  def with_fake_http(&)
    original = Net::HTTP.method(:start)
    Net::HTTP.singleton_class.define_method(:start) { |*a, **k, &b| FakeHTTP.start(*a, **k, &b) }
    yield
  ensure
    Net::HTTP.singleton_class.define_method(:start, original)
  end

  test "publishing fans out to subscribed webhooks with Helpjuice's payload and a valid signature" do
    assert @hook.secret.start_with?("whsec_")
    assert_not_equal @hook.secret, Webhook.connection.select_value("select secret from webhooks where id = #{@hook.id}"), "stored encrypted"

    with_fake_http do
      perform_enqueued_jobs do
        publish_article(title: "Refunds", body: "<p>x</p>", chapter: create_chapter)
      end
    end
    delivery = @hook.deliveries.sole
    assert_equal "delivered", delivery.status
    req = FakeHTTP.last_request
    body = JSON.parse(req.body)
    assert_equal "question_publish", body["event"]
    assert_equal "publish", body.dig("activity_fields", "action")
    assert_equal "Article", body.dig("activity_fields", "trackable_type")
    t = req["X-Helpvibe-Signature"][/t=(\d+)/, 1]
    expected = OpenSSL::HMAC.hexdigest("SHA256", @hook.secret, "#{t}.#{req.body}")
    assert_equal "t=#{t},v1=#{expected}", req["X-Helpvibe-Signature"]
    assert_equal 200, @hook.reload.last_response_code
  end

  test "failures retry on a schedule and finally die" do
    activity = Activity.create!(trackable_type: "article", trackable_id: 1, action: "publish")
    delivery = @hook.deliveries.create!(activity: activity)
    FakeHTTP.code = 500
    with_fake_http do
      5.times do |i|
        DeliverWebhookJob.perform_now(delivery.id)
        assert_equal "failed", delivery.reload.status
        assert_equal i + 1, delivery.attempt
      end
      DeliverWebhookJob.perform_now(delivery.id)
    end
    assert_equal "dead", delivery.reload.status
    assert_equal 6, delivery.attempt
  end

  test "network errors are retried too" do
    activity = Activity.create!(trackable_type: "article", trackable_id: 1, action: "publish")
    delivery = @hook.deliveries.create!(activity: activity)
    FakeHTTP.raise_error = Errno::ECONNREFUSED
    with_fake_http { DeliverWebhookJob.perform_now(delivery.id) }
    assert_equal "failed", delivery.reload.status
    assert_match "refused", delivery.error.downcase
  end

  test "private and metadata addresses are refused" do
    assert Webhook.private_address?("127.0.0.1")
    assert Webhook.private_address?("10.0.0.5")
    assert Webhook.private_address?("169.254.169.254")
    assert_not Webhook.private_address?("93.184.216.34")
  end

  test "events outside Helpjuice's list are rejected" do
    assert_not Webhook.new(url: "https://example.com", event: "everything").valid?
  end
end
