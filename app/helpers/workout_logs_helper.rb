module WorkoutLogsHelper
  # shortcuts:// URL that runs the user's "Shichimi to Health" Shortcut with the log as JSON text input.
  # Unverified on device (see AGENTS.md "Apple Health hand-off").
  def apple_health_shortcut_url(log)
    json = { name: log.workout_name, duration_minutes: (log.duration_seconds / 60.0).round(1),
             kcal: log.kcal, start: log.performed_at.iso8601 }.compact.to_json
    "shortcuts://run-shortcut?" + URI.encode_www_form(name: "Shichimi to Health", input: "text", text: json).gsub("+", "%20")
  end
end
