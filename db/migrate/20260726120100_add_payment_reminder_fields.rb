class AddPaymentReminderFields < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :last_reminded_at, :datetime
    add_column :properties, :reminders_enabled, :boolean, default: true, null: false
  end
end
