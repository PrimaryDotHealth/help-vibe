# Intercom ticket field settings we didn't have yet (replica/recon.md Part 3).
class AddTicketFieldSettings < ActiveRecord::Migration[8.1]
  def change
    change_table :ticket_type_attributes, bulk: true do |t|
      t.boolean :multiline, null: false, default: false
      t.boolean :required_to_close, null: false, default: false
      t.boolean :hidden_on_create, null: false, default: false
    end
    change_table :ticket_types, bulk: true do |t|
      t.boolean :description_visible, null: false, default: true    # default "description" field shown to customers
      t.boolean :description_required, null: false, default: false
    end

    reversible do |dir|
      dir.up do
        execute <<~SQL
          insert into ticket_types (name, description, category)
          select 'Question', 'Anything a customer asks that needs follow-up', 'customer'
          where not exists (select 1 from ticket_types);
          insert into ticket_type_states (ticket_type_id, state_id, position)
          select t.id, s.id, s.id from ticket_types t cross join ticket_states s
          where not exists (select 1 from ticket_type_states);
        SQL
      end
    end
  end
end
