class AddNameToTaxReports < ActiveRecord::Migration[8.1]
  def change
    add_column :tax_reports, :name, :string
  end
end
