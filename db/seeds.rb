# db/seeds.rb
# Creates a test user with three medications and a realistic varied adherence history.
# Idempotent: destroys and recreates the test user's medications on each run.

puts "Seeding test data..."

# ── Test user ──────────────────────────────────────────────────────────────────
user = User.find_or_initialize_by(email: "test@dispensed.dev")
if user.new_record?
  user.password              = "Password123!"
  user.password_confirmation = "Password123!"
  user.save!
  puts "  Created user: test@dispensed.dev / Password123!"
else
  puts "  Found existing user: test@dispensed.dev"
end

profile = user.patient_profile

# Clear existing seed medications so the file is safe to re-run
profile.medications.destroy_all
puts "  Cleared existing medications"

# ── Helpers ────────────────────────────────────────────────────────────────────
# Build a scheduled_for datetime matching the format used by GenerateDailyDosesJob
def scheduled_at(date, time_str)
  Time.zone.parse("#{date} #{time_str}")
end

# ── Medication 1: Lisinopril — good adherence (~80% taken) ────────────────────
lisinopril = profile.medications.create!(
  name:             "Lisinopril",
  dose:             "10mg",
  form:             "tablet",
  notes:            "For blood pressure. Take in the morning.",
  days_supply:      28,
  last_dispensed_on: 14.days.ago.to_date,
  active:           true
)

lisinopril_schedule = lisinopril.schedules.create!(
  time_of_day:  Time.zone.parse("08:00"),
  days_of_week: "daily",
  instructions: "Take with a glass of water"
)

lisinopril_status = lambda do |i|
  case i % 10
  when 9 then "missed"
  when 6 then "skipped"
  else        "taken"
  end
end

# ── Medication 2: Metformin — mixed adherence (~43% taken) ────────────────────
metformin = profile.medications.create!(
  name:             "Metformin",
  dose:             "500mg",
  form:             "tablet",
  notes:            "For type 2 diabetes. Take with food.",
  days_supply:      28,
  last_dispensed_on: 7.days.ago.to_date,
  active:           true
)

metformin_schedule = metformin.schedules.create!(
  time_of_day:  Time.zone.parse("08:00"),
  days_of_week: "daily",
  instructions: "Take with breakfast"
)

metformin_status = lambda do |i|
  case i % 7
  when 0, 1, 3 then "taken"
  when 2, 6    then "skipped"
  else              "missed"
  end
end

# ── Medication 3: Atorvastatin — poor adherence (~40% taken, Mon/Wed/Fri) ─────
atorvastatin = profile.medications.create!(
  name:             "Atorvastatin",
  dose:             "20mg",
  form:             "tablet",
  notes:            "For cholesterol. Take in the evening.",
  days_supply:      28,
  last_dispensed_on: 21.days.ago.to_date,
  active:           true
)

atorvastatin_schedule = atorvastatin.schedules.create!(
  time_of_day:  Time.zone.parse("21:00"),
  days_of_week: "monday,wednesday,friday",
  instructions: "Take after evening meal"
)

atorvastatin_status = lambda do |i|
  case i % 5
  when 0, 2 then "taken"
  when 1, 3 then "missed"
  else           "skipped"
  end
end

# ── Historical doses: 28 days ago → yesterday ─────────────────────────────────
puts "  Generating historical doses..."

date_range = (28.days.ago.to_date..1.day.ago.to_date).to_a

[
  { medication: lisinopril,   schedule: lisinopril_schedule,   time: "08:00", status_fn: lisinopril_status },
  { medication: metformin,    schedule: metformin_schedule,     time: "08:00", status_fn: metformin_status },
  { medication: atorvastatin, schedule: atorvastatin_schedule,  time: "21:00", status_fn: atorvastatin_status }
].each do |config|
  date_range.each_with_index do |date, i|
    next unless config[:schedule].active_on?(date)

    status       = config[:status_fn].call(i)
    scheduled_dt = scheduled_at(date, config[:time])

    dose = Dose.create!(
      medication:    config[:medication],
      schedule:      config[:schedule],
      scheduled_for: scheduled_dt,
      status:        status,
      taken_at:      status == "taken" ? scheduled_dt + rand(30..90).minutes : nil
    )
  end
end

puts ""
puts "✓ Seed complete."
puts "  Login:  test@dispensed.dev"
puts "  Pass:   Password123!"
puts "  Meds:   Lisinopril (good), Metformin (mixed), Atorvastatin (poor)"
