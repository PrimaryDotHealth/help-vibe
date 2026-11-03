# Staff accounts: the generator's users table plus the columns from
# replica/schema.sql (Helpjuice's five roles, lockout, sign-in tracking).
class ExtendUsers < ActiveRecord::Migration[8.1]
  ROLES = %w[superadmin admin collaborator draft_writer viewer].freeze

  def change
    change_table :users, bulk: true do |t|
      t.string :first_name, null: false, default: ""
      t.string :last_name, null: false, default: ""
      t.string :role, null: false, default: "viewer"
      t.boolean :active, null: false, default: true
      t.integer :failed_logins, null: false, default: 0
      t.datetime :locked_until
      t.datetime :last_sign_in_at
    end
    add_check_constraint :users, "role in (#{ROLES.map { "'#{_1}'" }.join(',')})", name: "users_role_check"
  end
end
