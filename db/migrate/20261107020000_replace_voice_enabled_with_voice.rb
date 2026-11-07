class ReplaceVoiceEnabledWithVoice < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :voice, :string, null: false, default: "female"
    execute "UPDATE users SET voice = 'off' WHERE voice_enabled = 0"
    remove_column :users, :voice_enabled
  end

  def down
    add_column :users, :voice_enabled, :boolean, null: false, default: true
    execute "UPDATE users SET voice_enabled = 0 WHERE voice = 'off'"
    remove_column :users, :voice
  end
end
