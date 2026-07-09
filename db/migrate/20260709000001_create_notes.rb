class CreateNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :notes do |t|
      t.references :landlord, null: false, foreign_key: true
      t.references :noteable, polymorphic: true, null: true
      t.string :title, null: false
      t.text :description, null: false
      t.date :due_date
      t.integer :status, null: false, default: 0
      t.datetime :completed_at

      t.timestamps
    end

    add_index :notes, [:landlord_id, :noteable_type, :noteable_id]
    add_index :notes, [:landlord_id, :status]
    add_index :notes, [:due_date]
  end
end
