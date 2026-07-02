class CreateExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses do |t|
      t.references :property, null: false, foreign_key: true
      t.date :date, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.integer :category, null: false
      t.string :description
      t.string :invoice_url

      t.timestamps
    end
  end
end
