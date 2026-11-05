class AddProfileToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :name, :string
    add_column :users, :time_zone, :string, null: false, default: "Asia/Tokyo"
    add_column :users, :weight_kg, :decimal, precision: 5, scale: 1
    add_column :users, :weekly_goal, :integer, null: false, default: 5
    add_column :users, :reminders_enabled, :boolean, null: false, default: false
    add_column :users, :reminder_time, :string, null: false, default: "07:00"
    add_column :users, :reminder_days, :string, null: false, default: "0123456" # wday digits, 0 = Sunday
    add_column :users, :last_reminded_on, :date
    add_column :users, :voice_enabled, :boolean, null: false, default: true
  end
end
