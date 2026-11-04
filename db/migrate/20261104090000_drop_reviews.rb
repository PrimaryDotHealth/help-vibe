# Article reviews were removed (2026-11-03): drafts are published directly by
# collaborators and above. Revision history and editor comments stay.
class DropReviews < ActiveRecord::Migration[8.1]
  def up
    drop_table :review_assignments
    drop_table :reviews
    execute "delete from settings where key like 'review.%'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "reviews were removed; restore from the CreateKnowledgeBase migration if needed"
  end
end
