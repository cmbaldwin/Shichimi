# Timing protocols (config/catalog/formats.yml). Not a DB table.
WorkoutFormat = Data.define(:key, :name, :spice, :ja, :heat, :work, :rest, :rounds, :round_rest, :stations, :summary, :science) do
  def self.all = @all ||= YAML.load_file(Rails.root.join("config/catalog/formats.yml")).map { new(**it.symbolize_keys) }
  def self.find(key) = all.find { it.key == key.to_s } || raise(KeyError, "unknown format #{key}")
  def self.keys = all.map(&:key)

  # Seconds for a circuit of n exercises: work + rest between intervals, round_rest between rounds, no trailing rest.
  def total_seconds(n)
    return 0 if n.zero?
    rounds * (n * work + (n - 1) * rest) + (rounds - 1) * round_rest
  end
end
