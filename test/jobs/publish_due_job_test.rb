require "test_helper"

class PublishDueJobTest < ActiveSupport::TestCase
  setup { @chapter = create_chapter }

  test "publishes scheduled drafts and takes down expired articles" do
    article = Article.start!(title: "New fees", category: @chapter, author: users(:one))
    version = article.versions.first
    version.save_revision!(body: "<p>2027 fees</p>", author: users(:one), base_revision_id: nil)
    version.update!(publish_at: 1.hour.from_now, expire_at: 2.hours.from_now)
    assert_equal "Goes live #{version.publish_at.strftime("%-d %b")}", article.reload.status_label

    PublishDueJob.perform_now
    assert_nil article.reload.live_version, "not yet"

    travel 61.minutes do
      PublishDueJob.perform_now
      assert article.reload.live_version
      assert Activity.where(action: "publish", automatic: true).exists?
    end
    travel 121.minutes do
      PublishDueJob.perform_now
      assert_nil article.reload.live_version
      assert_empty SearchIndex.search("fees", viewer: nil).first
    end
  end

  test "expiry must come after go-live" do
    article = Article.start!(title: "x", category: @chapter, author: users(:one))
    version = article.versions.first
    assert_not version.update(publish_at: 2.hours.from_now, expire_at: 1.hour.from_now)
  end
end
