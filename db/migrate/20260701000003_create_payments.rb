class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.references :rental_agreement, null: false, foreign_key: true
      t.date :due_date, null: false
      t.date :paid_date
      t.decimal :amount, precision: 10, scale: 2, null: false

      t.timestamps
    end
  end
end
