class RemoveInvoiceUrlFromExpenses < ActiveRecord::Migration[8.1]
  def change
    remove_column :expenses, :invoice_url, :string
  end
end
