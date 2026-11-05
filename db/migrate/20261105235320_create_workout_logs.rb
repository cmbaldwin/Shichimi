class CreateWorkoutLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :workout_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :workout, foreign_key: { on_delete: :nullify } # snapshot below survives workout deletion
      t.string :workout_name, null: false
      t.string :format, null: false
      t.integer :work_seconds, null: false
      t.integer :rest_seconds, null: false
      t.json :completed_slugs, null: false, default: [] # exercises actually finished, in order
      t.integer :duration_seconds, null: false, default: 0
      t.datetime :performed_at, null: false
      t.integer :rpe # Borg CR10, 1..10
      t.text :notes
      t.timestamps
    end
    add_index :workout_logs, [ :user_id, :performed_at ]
  end
end
