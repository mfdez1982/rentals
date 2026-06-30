class CreateProperties < ActiveRecord::Migration[8.1]
  def change
    create_table :properties do |t|
      t.references :landlord, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :rented, null: false, default: false

      t.timestamps
    end
  end
end
