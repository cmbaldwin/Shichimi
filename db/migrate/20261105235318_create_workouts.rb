class CreateWorkouts < ActiveRecord::Migration[8.1]
  def change
    create_table :workouts do |t|
      t.references :user, foreign_key: true # nil = built-in catalog workout
      t.string :name, null: false
      t.string :slug # catalog workouts only
      t.string :format, null: false
      t.json :exercise_slugs, null: false, default: []
      t.integer :level, null: false, default: 2
      t.string :focus, null: false, default: "full"
      t.text :about
      t.boolean :low_impact, null: false, default: false
      t.boolean :needs_floor, null: false, default: true
      t.string :equipment, null: false, default: "" # e.g. "chair wall"
      t.integer :total_seconds, null: false, default: 0
      t.timestamps
    end
    add_index :workouts, :slug, unique: true
    add_index :workouts, [ :format, :focus, :level ]
  end
end
