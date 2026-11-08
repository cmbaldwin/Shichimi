class AddFigureToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :figure, :string, default: "male", null: false
  end
end
