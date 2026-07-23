class CreateTaxReports < ActiveRecord::Migration[8.1]
  def change
    create_table :tax_reports do |t|
      t.references :property, null: false, foreign_key: true
      t.integer :year, null: false
      t.integer :total_days, null: false
      t.integer :active_rental_days, null: false
      t.decimal :pro_rata_ratio, precision: 5, scale: 4, null: false
      t.decimal :total_gross_income, precision: 10, scale: 2, null: false
      t.json :expense_lines, null: false, default: []

      t.timestamps
    end

    add_index :tax_reports, [:property_id, :year]
  end
end
