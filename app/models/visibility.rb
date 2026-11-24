# Who can see what, in one place (replica/architecture.md, "Visibility rules").
#
#   public    everyone
#   internal  staff: signed-in users, the widget with a staff token, API keys
#   private   superadmins, plus people/groups listed in article_access /
#             category_access
#   url_only  never listed or searched; opens for anyone allowed "public" by link
#
# A viewer can also be limited to collections (an embed asked for
# ?collections=acme,general): then only articles in at least one of them pass.
# That narrows what is shown; it never widens access.
#
# An article is visible only if its chapter is too (most restrictive wins;
# Category keeps children at least as restricted as their parent).
# Everything is expressed as SQL so lists, counts and search never leak.
class Visibility
  Viewer = Data.define(:user_id, :group_ids, :staff, :superadmin, :collection_ids) do
    # collection_ids: nil means every collection (no filter).
    def initialize(user_id:, group_ids:, staff:, superadmin:, collection_ids: nil) = super

    def self.anonymous = new(user_id: nil, group_ids: [], staff: false, superadmin: false)
    def self.staff_token = new(user_id: nil, group_ids: [], staff: true, superadmin: false)

    def self.for(user)
      return anonymous unless user&.active?
      new(user_id: user.id, group_ids: user.group_ids, staff: true, superadmin: user.superadmin?)
    end

    def in_collections(ids) = with(collection_ids: ids.nil? ? nil : Array(ids).map(&:to_i))
  end

  def self.viewer(user_or_viewer)
    user_or_viewer.is_a?(Viewer) ? user_or_viewer : Viewer.for(user_or_viewer)
  end

  # SQL condition over an articles alias and a categories alias.
  def self.sql(viewer, article: "articles", category: "categories", by_link: false)
    v = viewer(viewer)
    article_ok = level_sql(v, "#{article}.accessibility", "article_access", "article_id", "#{article}.id", by_link:)
    category_ok = level_sql(v, "#{category}.accessibility", "category_access", "category_id", "#{category}.id", by_link: false)
    "(#{article}.archived_at is null and #{category}.archived_at is null and #{article_ok} and #{category_ok}#{collection_sql(v, article)})"
  end

  def self.collection_sql(v, article)
    return "" if v.collection_ids.nil?
    return " and false" if v.collection_ids.empty?
    " and exists (select 1 from article_collections ac where ac.article_id = #{article}.id " \
      "and ac.collection_id in (#{v.collection_ids.map(&:to_i).join(",")}))"
  end

  # SQL condition for a chapter (category) on its own.
  def self.category_sql(viewer, category: "categories")
    "(#{category}.archived_at is null and #{level_sql(viewer(viewer), "#{category}.accessibility", "category_access", "category_id", "#{category}.id", by_link: false)})"
  end

  def self.level_sql(v, column, acl_table, acl_fk, id_expr, by_link:)
    ors = [ "#{column} = 'public'" ]
    ors << "#{column} = 'url_only'" if by_link
    ors << "#{column} = 'internal'" if v.staff
    if v.superadmin
      ors << "#{column} = 'private'"
    elsif v.user_id
      groups = v.group_ids.any? ? " or acl.group_id in (#{v.group_ids.map(&:to_i).join(",")})" : ""
      ors << "(#{column} = 'private' and exists (select 1 from #{acl_table} acl where acl.#{acl_fk} = #{id_expr} " \
             "and (acl.user_id = #{v.user_id.to_i}#{groups})))"
    end
    "(#{ors.join(" or ")})"
  end
end
