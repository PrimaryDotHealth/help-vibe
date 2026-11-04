# Who opened a ticket on the team's side (shown as "Created by" on the ticket).
class AddCreatedByToThreads < ActiveRecord::Migration[8.1]
  def change
    add_reference :threads, :created_by, foreign_key: { to_table: :users, on_delete: :nullify }, index: true
  end
end
