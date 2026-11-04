# Every minute: publish drafts whose go-live time has passed, and take down
# live versions whose expiry has passed. Recorded as automatic activities.
class PublishDueJob < ApplicationJob
  queue_as :default

  def perform
    ArticleVersion.due_to_publish.find_each do |version|
      version.publish!(by: nil) if version.current_revision
    end
    ArticleVersion.due_to_expire.find_each { _1.unpublish!(by: nil) }
  end
end
