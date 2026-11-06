# frozen_string_literal: true

class CreateUchujinTables < ActiveRecord::Migration[8.1]
  def change
    create_table :uchujin_faults do |t|
      t.string :fingerprint, null: false
      t.string :class_name, null: false
      t.text :message
      t.string :component, default: "web", null: false
      t.string :environment, null: false
      t.string :status, default: "unresolved", null: false
      t.integer :occurrences_count, default: 0, null: false
      t.datetime :first_seen_at
      t.datetime :last_seen_at
      t.datetime :resolved_at
      t.datetime :last_notified_at
      t.bigint :assignee_id
      t.string :revision
      t.json :tags, default: []
      t.json :sample_context, default: {}

      t.timestamps
    end
    add_index :uchujin_faults, :fingerprint, unique: true
    add_index :uchujin_faults, :status
    add_index :uchujin_faults, :last_seen_at
    add_index :uchujin_faults, :environment
    add_index :uchujin_faults, :class_name
    add_index :uchujin_faults, :component

    create_table :uchujin_occurrences do |t|
      t.references :fault, null: false, foreign_key: { to_table: :uchujin_faults }, index: true
      t.datetime :occurred_at, null: false
      t.text :message
      t.json :backtrace, default: []
      t.json :backtrace_app, default: []
      t.json :source_context_lines, default: []
      t.json :cause
      t.json :context, default: {}
      t.json :breadcrumbs, default: []
      t.json :server_stats, default: {}
      t.json :params, default: {}
      t.json :request_metadata, default: {}
      t.json :client_info, default: {}
      t.string :component
      t.string :environment
      t.string :revision

      t.timestamps
    end
    add_index :uchujin_occurrences, :occurred_at

    create_table :uchujin_comments do |t|
      t.references :fault, null: false, foreign_key: { to_table: :uchujin_faults }, index: true
      t.text :body, null: false
      t.bigint :author_id
      t.string :author_name

      t.timestamps
    end

    create_table :uchujin_deployments do |t|
      t.string :sha, null: false
      t.string :environment, null: false
      t.datetime :deployed_at, null: false
      t.string :repository
      t.string :user
      t.json :metadata, default: {}

      t.timestamps
    end
    add_index :uchujin_deployments, [ :environment, :deployed_at ]

    create_table :uchujin_uptime_checks do |t|
      t.string :url, null: false
      t.string :status, default: "unknown", null: false
      t.integer :response_time_ms
      t.integer :status_code
      t.text :error_message
      t.datetime :checked_at, null: false

      t.timestamps
    end
    add_index :uchujin_uptime_checks, [ :url, :checked_at ]

    create_table :uchujin_check_ins do |t|
      t.string :name, null: false
      t.integer :expected_every_seconds
      t.datetime :last_seen_at
      t.integer :ping_count, default: 0, null: false
      t.json :metadata, default: {}

      t.timestamps
    end
    add_index :uchujin_check_ins, :name, unique: true

    create_table :uchujin_notifications do |t|
      t.references :fault, foreign_key: { to_table: :uchujin_faults }, index: true
      t.string :channel, null: false
      t.string :status, default: "sent"
      t.json :payload, default: {}
      t.datetime :sent_at

      t.timestamps
    end
  end
end
