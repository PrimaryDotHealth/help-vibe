require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  setup { @chapter = create_chapter }

  test "codes come from the chapter and count up" do
    a = Article.start!(title: "One", category: @chapter, author: users(:one))
    b = Article.start!(title: "Two", category: @chapter, author: users(:one))
    assert_equal [ "SCH·01", "SCH·02" ], [ a.code, b.code ]
  end

  test "sub-chapter articles use the parent's code" do
    sub = Category.create!(name: "Calendar sync", parent: @chapter)
    assert_equal "SCH·01", Article.start!(title: "Google", category: sub, author: users(:one)).code
  end

  test "codes are normalised from loose input" do
    assert_equal "SCH·07", Article.normalize_code("sch7")
    assert_equal "BIL·12", Article.normalize_code(" bil-12 ")
    assert_nil Article.normalize_code("hello")
  end

  test "publishing makes one live version and editing starts a new draft" do
    article = publish_article(title: "Reschedule", body: "<p>Cancelling frees the slot.</p>", chapter: @chapter)
    assert_equal "Live", article.status_label

    draft = article.working_version!(author: users(:two))
    assert_equal 2, draft.number
    assert draft.draft?
    assert_equal "Cancelling frees the slot.", draft.current_revision.body_text
    assert_equal "Live, editing v2", article.reload.status_label
    assert_equal article.versions.first, article.live_version, "the live copy is untouched until publish"

    draft.save_revision!(body: "<p>New words</p>", author: users(:two), base_revision_id: draft.current_revision_id)
    draft.publish!(by: users(:two))
    assert_equal draft, article.reload.live_version
    assert_equal 1, article.versions.where(is_default: true).count
  end

  test "saving on a stale revision is refused" do
    article = publish_article(title: "A", body: "<p>x</p>", chapter: @chapter)
    draft = article.working_version!(author: users(:one))
    stale = draft.current_revision_id
    draft.save_revision!(body: "<p>Lee's change</p>", author: users(:two), base_revision_id: stale)
    assert_raises(ArticleVersion::StaleRevision) do
      draft.save_revision!(body: "<p>Dana's change</p>", author: users(:one), base_revision_id: stale)
    end
  end

  test "the database allows only one live version per language" do
    article = publish_article(title: "A", body: "<p>x</p>", chapter: @chapter)
    v2 = article.versions.create!(number: 2, title: "A", status: "published")
    assert_raises(ActiveRecord::RecordNotUnique) { v2.update_column(:is_default, true) }
  end
end
