# S20 (part 2): outgoing webhooks. Admins only.
class Admin::WebhooksController < Admin::BaseController
  before_action { head :forbidden unless Current.user.admin? }
  before_action :set_webhook, only: %i[show update destroy toggle test]

  def index = @webhooks = Webhook.order(:event, :id)
  def new = @webhook = Webhook.new

  def create
    @webhook = Webhook.new(params.require(:webhook).permit(:url, :event).merge(created_by: Current.user))
    @webhook.save ? redirect_to(admin_webhook_path(@webhook), notice: "Webhook added") : render(:new, status: :unprocessable_entity)
  end

  def show
    @deliveries = @webhook.deliveries.includes(:activity).order(created_at: :desc).limit(50)
  end

  def update
    @webhook.update(params.require(:webhook).permit(:url, :event)) ? redirect_to(admin_webhook_path(@webhook), notice: "Saved") : render(:show, status: :unprocessable_entity)
  end

  def toggle
    @webhook.update!(enabled: !@webhook.enabled)
    redirect_to admin_webhook_path(@webhook), notice: @webhook.enabled ? "Enabled" : "Paused"
  end

  # Sends a real delivery for a synthetic activity, so receivers can test signatures.
  def test
    activity = Activity.create!(trackable_type: "setting", trackable_id: 0, owner: Current.user, action: "test", extra: { test: true })
    delivery = @webhook.deliveries.create!(activity: activity)
    DeliverWebhookJob.perform_later(delivery.id)
    redirect_to admin_webhook_path(@webhook), notice: "Test sent"
  end

  def destroy
    @webhook.destroy!
    redirect_to admin_webhooks_path, notice: "Webhook deleted"
  end

  private
    def set_webhook = @webhook = Webhook.find(params[:id])
end
