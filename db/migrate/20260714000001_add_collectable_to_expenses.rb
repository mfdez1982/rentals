class AddCollectableToExpenses < ActiveRecord::Migration[8.1]
  def change
    add_column :expenses, :collectable, :boolean, null: false, default: false
    add_column :expenses, :period_start, :date
    add_column :expenses, :period_end, :date
  end
end
