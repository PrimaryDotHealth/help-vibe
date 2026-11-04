# Content activity log, Helpjuice-shaped. Drives the activity screen and webhooks.
class Activity < ApplicationRecord
  belongs_to :owner, class_name: "User", optional: true

  # our (trackable_type, action) -> Helpjuice webhook event
  EVENTS = {
    %w[article create] => "question_create", %w[article update] => "question_update",
    %w[article publish] => "question_publish", %w[article unpublish] => "question_update",
    %w[article archive] => "question_archive", %w[article delete] => "question_delete",
    %w[category create] => "category_create", %w[category update] => "category_update", %w[category delete] => "category_delete",
    %w[user create] => "user_create", %w[user update] => "user_update",
    %w[comment create] => "comment_create", %w[comment update] => "comment_update"
  }.freeze

  after_create_commit { FanOutActivityJob.perform_later(id) if webhook_event && Webhook.enabled.where(event: webhook_event).exists? }

  def self.record!(trackable, action, by: nil, automatic: false, extra: {})
    create!(trackable_type: trackable.class.name.underscore, trackable_id: trackable.id,
            owner: by, action: action.to_s, automatic: automatic, extra: extra)
  end

  def webhook_event = EVENTS[[ trackable_type, action ]]

  def trackable
    case trackable_type
    when "article" then Article.find_by(id: trackable_id)
    when "category" then Category.find_by(id: trackable_id)
    when "user" then User.find_by(id: trackable_id)
    end
  end
end
