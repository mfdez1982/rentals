class RemoveRentedFromProperties < ActiveRecord::Migration[8.1]
  def change
    remove_column :properties, :rented, :boolean
  end
end
