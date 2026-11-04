require "test_helper"

class VisibilityTest < ActiveSupport::TestCase
  setup do
    @chapter = create_chapter
    @private = publish_article(title: "Disputed invoices playbook", body: "<p>Escalate disputes to billing.</p>",
                               chapter: @chapter, accessibility: "private")
    @support = Group.create!(name: "Support")
  end

  def sees?(user) = @private.visible_to?(user)

  test "private articles: superadmins always, others only when shared with them or their group" do
    assert sees?(users(:one)), "superadmin"
    assert_not sees?(users(:two)), "collaborator not shared"
    assert_not sees?(nil), "anonymous"

    @private.accessor_keys = [ "user:#{users(:two).id}" ]
    assert sees?(users(:two)), "shared with the person"

    @private.accessor_keys = [ "group:#{@support.id}" ]
    assert_not sees?(users(:viewer))
    @support.users << users(:viewer)
    assert sees?(users(:viewer).reload), "shared with their group"
  end

  test "private articles stay out of lists and search unless shared" do
    assert_empty Article.listed_for(users(:two))
    assert_empty SearchIndex.search("disputes", viewer: users(:two)).first
    @private.accessor_keys = [ "user:#{users(:two).id}" ]
    assert_equal [ @private ], Article.listed_for(users(:two)).to_a
    assert_equal [ @private.code ], SearchIndex.search("disputes", viewer: users(:two)).first.map(&:code)
  end

  test "deactivated staff see only public content" do
    internal = publish_article(title: "Internal", body: "<p>x</p>", chapter: @chapter, accessibility: "internal")
    users(:viewer).update!(active: false)
    assert_not internal.visible_to?(users(:viewer))
  end

  test "url_only opens by link but is never listed" do
    hidden = publish_article(title: "Beta feature", body: "<p>secret beta</p>", chapter: @chapter, accessibility: "url_only")
    assert hidden.visible_to?(nil)
    assert_not_includes Article.listed_for(nil), hidden
    assert_empty SearchIndex.search("beta", viewer: nil).first
  end

  test "a sub-chapter can't be more open than its parent, and tightening a parent tightens children" do
    sub = Category.create!(name: "Calendar sync", parent: @chapter)
    @chapter.update!(accessibility: "internal")
    assert_equal "internal", sub.reload.accessibility
    sub.accessibility = "public"
    assert_not sub.valid?
  end

  test "group auto-join by email domain" do
    team = Group.create!(name: "Staff", domain_list: "example.com, @Other.org")
    assert_equal %w[example.com other.org], team.auto_join_domains
    Group.auto_join!(users(:writer))
    assert_includes team.users.reload, users(:writer)
  end
end
