# Static catalog (config/catalog/exercises.yml + motions/<slug>.yml). Not a DB table.
Exercise = Data.define(:slug, :name, :ja, :category, :impact, :level, :equipment, :floor, :sides,
                       :muscles, :cues, :easier, :harder, :met, :reference, :motion) do
  def self.categories = %w[cardio lower upper core]

  def self.all = @all ||= load_catalog
  def self.find(slug) = index.fetch(slug.to_s)
  def self.find_by(slug) = index[slug.to_s]
  def self.index = @index ||= all.index_by(&:slug)
  def self.slugs = index.keys
  def self.reload! = (@all = @index = @videos = nil)
  # Pre-rendered loops in public/videos/<slug>.mp4 (+ .webp poster), see script/vork.
  def self.videos = @videos ||= Dir[Rails.public_path.join("videos/**/*.mp4")].map { it.delete_prefix("#{Rails.public_path}/videos/").delete_suffix(".mp4") }.to_set

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
  # "/videos/<figure>/<slug>" (+ ".mp4" / ".webp"), falling back to the older single-figure render, else nil.
  def video(figure = "male") = [ "#{figure}/#{slug}", slug ].find { Exercise.videos.include?(it) }&.then { "/videos/#{it}" }
  def to_player(figure = "male") = { slug:, name:, category:, sides: !!sides, cues: Array(cues), video: video(figure), motion: motion.merge("category" => category) }
end
