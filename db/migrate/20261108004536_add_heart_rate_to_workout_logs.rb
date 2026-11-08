class AddHeartRateToWorkoutLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :workout_logs, :avg_hr, :integer
    add_column :workout_logs, :max_hr, :integer
  end
end
