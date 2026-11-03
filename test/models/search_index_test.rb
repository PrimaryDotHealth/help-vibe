require "test_helper"

class SearchIndexTest < ActiveSupport::TestCase
  setup do
    @chapter = create_chapter
    @public = publish_article(title: "Reschedule or cancel an appointment", body: "<p>Cancelling frees the slot straight away.</p>",
                              chapter: @chapter, keywords: "move appointment")
    @internal = publish_article(title: "Cancel on behalf of a clinic", body: "<p>Staff-only cancelling steps.</p>",
                                chapter: @chapter, accessibility: "internal")
  end

  test "stemmed full-text search with highlighting" do
    results, fuzzy = SearchIndex.search("cancelled", viewer: nil)
    assert_not fuzzy
    assert_equal [ @public.code ], results.map(&:code)
    assert_includes results.first.snippet, "<mark>Cancelling</mark>"
  end

  test "typos fall back to close matches" do
    results, fuzzy = SearchIndex.search("apointment", viewer: nil)
    assert fuzzy
    assert_equal @public.code, results.first.code
  end

  test "internal articles are hidden from anonymous readers but shown to staff" do
    anon, = SearchIndex.search("cancelling", viewer: nil)
    staff, = SearchIndex.search("cancelling", viewer: users(:viewer))
    assert_equal [ @public.code ], anon.map(&:code)
    assert_equal [ @internal.code, @public.code ].sort, staff.map(&:code).sort
  end

  test "an article inside a staff-only chapter is hidden even if the article is public" do
    hidden = create_chapter(code: "SUP", name: "Support playbook", accessibility: "internal")
    publish_article(title: "Escalation steps", body: "<p>Escalate disputes.</p>", chapter: hidden)
    assert_empty SearchIndex.search("escalate", viewer: nil).first
    assert_equal 1, SearchIndex.search("escalate", viewer: users(:viewer)).first.size
  end

  test "unpublishing removes the article from search" do
    @public.live_version.unpublish!(by: users(:one))
    assert_empty SearchIndex.search("slot", viewer: nil).first
  end
end
