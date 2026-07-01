class CreateRentalAgreements < ActiveRecord::Migration[8.1]
  def change
    create_table :rental_agreements do |t|
      t.references :property, null: false, foreign_key: true
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.decimal :rent_amount, precision: 10, scale: 2, null: false

      t.timestamps
    end
  end
end
