# Static catalog (config/catalog/exercises.yml + motions/<slug>.yml). Not a DB table.
Exercise = Data.define(:slug, :name, :ja, :category, :impact, :level, :equipment, :floor, :sides,
                       :muscles, :cues, :easier, :harder, :met, :motion) do
  def self.categories = %w[cardio lower upper core]

  def self.all = @all ||= load_catalog
  def self.find(slug) = index.fetch(slug.to_s)
  def self.find_by(slug) = index[slug.to_s]
  def self.index = @index ||= all.index_by(&:slug)
  def self.slugs = index.keys
  def self.reload! = (@all = @index = nil)

  def self.load_catalog
    dir = Rails.root.join("config/catalog")
    YAML.load_file(dir.join("exercises.yml")).map do |h|
      motion_file = dir.join("motions/#{h["slug"]}.yml")
      motion = motion_file.exist? ? YAML.load_file(motion_file) : { "tempo" => 2, "keys" => [ {} ] }
      new(**members.to_h { [ it, nil ] }.merge(h.symbolize_keys.slice(*members)), motion: motion)
    end
  end

  def to_param = slug
  def low_impact? = impact == "low"
  def to_player = { slug:, name:, category:, sides: !!sides, cues: Array(cues), motion: }
end
