class CreateLandlords < ActiveRecord::Migration[8.1]
  def change
    create_table :landlords do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :phone

      t.timestamps
    end
  end
end
