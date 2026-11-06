# Analytics for one user, computed in Ruby in the user's time zone.
# ponytail: loads every log of one user into memory and tallies in Ruby. Fine up to tens of thousands of
# logs; past that, push the group-bys into SQL (strftime with a zone offset) or cache per day.
class Stats
  WHO_VIGOROUS_MINUTES = 75 # WHO 2020: 75 min vigorous aerobic per week
  WHO_STRENGTH_DAYS = 2     # muscle-strengthening on 2+ days per week
  HEATMAP_WEEKS = 26
  SERIES_WEEKS = 12
  STRENGTH_CATEGORIES = %w[lower upper].freeze

  attr_reader :user, :today

  def initialize(user, today: user.today)
    @user = user
    @today = today
  end

  def any? = entries.any?

  # Each log with its local date, oldest first.
  def entries
    @entries ||= user.workout_logs.order(:performed_at).map do |log|
      { log:, date: log.performed_at.in_time_zone(user.zone).to_date }
    end
  end

  def days_set = @days_set ||= entries.to_set { it[:date] }

  def current_streak
    d = days_set.include?(today) ? today : today - 1
    n = 0
    while days_set.include?(d)
      n += 1
      d -= 1
    end
    n
  end

  def longest_streak
    best = run = 0
    prev = nil
    days_set.sort.each do |d|
      run = prev && d == prev + 1 ? run + 1 : 1
      best = run if run > best
      prev = d
    end
    best
  end

  def week_start = today.beginning_of_week(:monday)

  def week = (0..6).map { day_row(week_start + it) }

  def weekly_goal_progress = { done_days: week.count { it[:done] }, goal: user.weekly_goal }

  def days_since_last_workout = entries.empty? ? nil : (today - entries.last[:date]).to_i

  def totals
    logs = entries.map { it[:log] }
    {
      sessions: logs.size,
      minutes: (logs.sum(&:duration_seconds) / 60.0).round,
      work_minutes: (logs.sum(&:work_total) / 60.0).round,
      kcal: user.weight_kg ? logs.sum { it.kcal(user.weight_kg) } : nil
    }
  end

  # 26 weeks, Monday-aligned, through the end of this week (future days flagged) so columns are whole weeks.
  def heatmap
    start = week_start - (HEATMAP_WEEKS - 1) * 7
    (0...HEATMAP_WEEKS * 7).map { day_row(start + it).merge(future: start + it > today) }
  end

  def weekly_series
    (0...SERIES_WEEKS).map do |i|
      from = week_start - (SERIES_WEEKS - 1 - i) * 7
      es = entries.select { (from..from + 6).cover?(it[:date]) }
      { week_start: from, minutes: minutes_of(es), sessions: es.size }
    end
  end

  # WHO weekly targets for the current week. Vigorous minutes = interval work time (all-out by design).
  def who_targets
    es = this_week_entries
    strength_days = es.select { |e| e[:log].exercises.any? { STRENGTH_CATEGORIES.include?(it.category) } }.map { it[:date] }.uniq.size
    {
      vigorous: { value: (es.sum { it[:log].work_total } / 60.0).round, target: WHO_VIGOROUS_MINUTES },
      strength_days: { value: strength_days, target: WHO_STRENGTH_DAYS }
    }
  end

  # Work seconds per category over the last 30 days (today included).
  def category_balance
    from = today - 29
    totals = Exercise.categories.index_with { 0 }
    entries.select { it[:date] >= from }.each do |e|
      e[:log].exercises.each { |ex| totals[ex.category] += e[:log].work_seconds if totals.key?(ex.category) }
    end
    totals
  end

  def top_workouts(n = 5)
    entries.map { it[:log].workout_name }.tally.sort_by { |name, c| [ -c, name ] }.first(n)
  end

  def top_exercises(n = 5)
    entries.flat_map { it[:log].completed_slugs }.tally.sort_by { |slug, c| [ -c, slug ] }.first(n)
      .map { |slug, c| [ Exercise.find_by(slug)&.name || slug, c, Exercise.find_by(slug)&.category ] }
  end

  def hour_histogram
    h = Array.new(24, 0)
    entries.each { h[it[:log].performed_at.in_time_zone(user.zone).hour] += 1 }
    h
  end

  # Monday..Sunday
  def weekday_histogram
    h = Array.new(7, 0)
    entries.each { h[it[:date].cwday - 1] += 1 }
    h
  end

  def rpe_trend = entries.filter_map { it[:log].rpe }.last(20)

  def rpe_average
    t = entries.filter_map { it[:log].rpe }
    t.empty? ? nil : (t.sum.to_f / t.size).round(1)
  end

  # Seven Lucky Gods (Shichifuku-jin), unlocked by milestones. Streak gods use longest_streak so they stay unlocked.
  # format = the Nanairo format whose color the medallion wears.
  GODS = [
    { key: "ebisu", name: "Ebisu", ja: "恵比寿", format: "classic", kind: :total, goal: 1, blurb: "Cast the first line. Luck bites the ones who show up." },
    { key: "daikokuten", name: "Daikokuten", ja: "大黒天", format: "sprint", kind: :streak, goal: 3, blurb: "Three days running, and the rice bag gets heavier." },
    { key: "benzaiten", name: "Benzaiten", ja: "弁財天", format: "tabata", kind: :streak, goal: 7, blurb: "A full week. She strums a biwa in your honor." },
    { key: "bishamonten", name: "Bishamonten", ja: "毘沙門天", format: "fifty_ten", kind: :total, goal: 25, blurb: "25 workouts. The warrior nods, barely." },
    { key: "hotei", name: "Hotei", ja: "布袋", format: "forty_twenty", kind: :streak, goal: 21, blurb: "Three weeks straight. A habit with a happy belly." },
    { key: "fukurokuju", name: "Fukurokuju", ja: "福禄寿", format: "double", kind: :total, goal: 100, blurb: "100 workouts. That forehead is wisdom, not a plank." },
    { key: "jurojin", name: "Jurōjin", ja: "寿老人", format: "easy", kind: :streak, goal: 100, blurb: "A hundred days. Longevity is just consistency, aged." }
  ].freeze

  def lucky_gods
    GODS.map do |g|
      value = g[:kind] == :total ? entries.size : longest_streak
      on = g[:kind] == :total ? entries[g[:goal] - 1]&.dig(:date) : streak_reached_on(g[:goal])
      g.slice(:key, :name, :ja, :blurb, :format).merge(unlocked: !on.nil?, unlocked_on: on, progress: [ value, g[:goal] ].min, goal: g[:goal])
    end
  end

  private

  # First date a run of n consecutive workout days was completed.
  def streak_reached_on(n)
    run = 0
    prev = nil
    days_set.sort.each do |d|
      run = prev && d == prev + 1 ? run + 1 : 1
      return d if run >= n
      prev = d
    end
    nil
  end

  def minutes_of(es) = (es.sum { it[:log].duration_seconds } / 60.0).round

  def this_week_entries = entries.select { (week_start..week_start + 6).cover?(it[:date]) }

  def by_date = @by_date ||= entries.group_by { it[:date] }

  def day_row(date)
    es = by_date.fetch(date, [])
    { date:, done: es.any?, minutes: minutes_of(es) }
  end
end
