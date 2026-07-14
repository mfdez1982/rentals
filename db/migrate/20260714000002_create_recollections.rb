class CreateRecollections < ActiveRecord::Migration[8.1]
  def change
    create_table :recollections do |t|
      t.references :expense, null: false, foreign_key: true
      t.references :rental_agreement, null: false, foreign_key: true
      t.references :agreement_tenant, null: true, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.date :due_date
      t.integer :status, null: false, default: 0
      t.date :paid_date

      t.timestamps
    end

    add_index :recollections, [ :expense_id, :rental_agreement_id, :agreement_tenant_id ],
      unique: true,
      name: "index_recollections_on_expense_agreement_tenant_unique"
    add_index :recollections, [ :expense_id, :rental_agreement_id ],
      unique: true,
      where: "agreement_tenant_id IS NULL",
      name: "index_recollections_on_expense_agreement_no_payer_unique"
  end
end
