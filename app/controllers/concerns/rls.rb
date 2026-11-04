# Sets the row-level-security context (app.* settings) on this request's
# database connection, and always clears it afterwards: Puma reuses
# connections across requests. The policies apply when the app connects as a
# role that doesn't own the tables (production; see replica/deploy.md).
module Rls
  extend ActiveSupport::Concern

  KEYS = %w[actor_type user_id contact_id see_all see_all_contacts compliance].freeze

  def self.with(actor_type:, user: nil, contact: nil)
    conn = ActiveRecord::Base.connection
    values = {
      "actor_type" => actor_type, "user_id" => user&.id.to_s, "contact_id" => contact&.id.to_s,
      "see_all" => (user && (user.admin? || user.permissions.include?("see_all_threads")) ? "on" : ""),
      "see_all_contacts" => (user && (user.admin? || user.permissions.include?("see_all_contacts")) ? "on" : ""),
      "compliance" => (user && (user.superadmin? || user.permissions.include?("compliance")) ? "on" : "")
    }
    set(conn, values)
    yield
  ensure
    set(conn, KEYS.index_with { "" }) if conn
  end

  def self.set(conn, values)
    sql = values.map { |k, v| "set_config(#{conn.quote("app.#{k}")}, #{conn.quote(v)}, false)" }.join(", ")
    conn.execute("select #{sql}")
  end
end
