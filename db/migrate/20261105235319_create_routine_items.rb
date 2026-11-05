class CreateRoutineItems < ActiveRecord::Migration[8.1]
  def change
    create_table :routine_items do |t|
      t.references :user, null: false, foreign_key: true
      t.references :workout, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :routine_items, [ :user_id, :workout_id ], unique: true
  end
end
