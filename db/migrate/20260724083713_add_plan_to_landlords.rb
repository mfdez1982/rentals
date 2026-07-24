class AddPlanToLandlords < ActiveRecord::Migration[8.1]
  def change
    add_column :landlords, :plan, :integer, null: false, default: 0
  end
end
