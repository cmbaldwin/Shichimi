module FlowsHelper
  def mmss(seconds) = format("%d:%02d", *seconds.to_i.divmod(60))

  def heat_marks(n) = tag.span("🌶" * n, class: "heat", title: "Heat #{n}/5")

  def ago(time) = "#{time_ago_in_words(time)} ago"

  def level_label(level) = %w[Easy Medium Hard][level.to_i - 1]

  def workout_flags(w)
    [ ("Low impact" if w.low_impact), ("No floor" unless w.needs_floor), ("No equipment" if w.equipment.blank?) ].compact
  end

  def category_summary(w)
    w.exercises.map(&:category).tally.sort_by { -it.last }.map { |c, n| tag.span("#{c} #{n}", class: "chip", data: { category: c }) }.join.html_safe
  end
end
