namespace :dev do
  desc "Recreate ~6 months of plausible workout logs for the demo user (idempotent)"
  task sample_logs: :environment do
    abort "dev only" unless Rails.env.development?
    user = User.find_by!(email_address: "demo@shichimi.test")
    user.update!(weight_kg: user.weight_kg || 70)
    user.workout_logs.delete_all
    rng = Random.new(7)
    catalog = Workout.catalog.to_a
    fallback_slugs = Exercise.slugs
    zone = user.zone

    ((user.today - 183)..user.today).each do |date|
      next if rng.rand < (date.on_weekend? ? 0.45 : 0.3) # gaps
      next if date.between?(user.today - 40, user.today - 32) # a break
      (rng.rand < 0.1 ? 2 : 1).times do |n|
        hour = n.zero? ? [ 6, 6, 7, 7, 7, 8, 8, 12, 18, 21 ].sample(random: rng) : 19
        at = zone.local(date.year, date.month, date.day, hour, rng.rand(60))
        next if at > Time.current
        if (w = catalog.sample(random: rng))
          f = w.workout_format
          attrs = { workout: w, workout_name: w.name, format: w.format, work_seconds: f.work, rest_seconds: f.rest,
                    completed_slugs: w.exercise_slugs * f.rounds }
          secs = w.total_seconds + Workout::PREP_SECONDS
        else
          f = WorkoutFormat.find("classic")
          slugs = fallback_slugs.sample(7, random: rng)
          attrs = { workout: nil, workout_name: "Sample circuit", format: f.key, work_seconds: f.work, rest_seconds: f.rest, completed_slugs: slugs }
          secs = f.total_seconds(7) + Workout::PREP_SECONDS
        end
        user.workout_logs.create!(attrs.merge(performed_at: at, duration_seconds: secs,
                                              rpe: rng.rand < 0.6 ? rng.rand(4..9) : nil))
      end
    end
    puts "Created #{user.workout_logs.count} logs for #{user.email_address}"
  end
end
