class GenerateDailyDosesJob < ApplicationJob
  queue_as :default

  def perform(date = Date.current)
    User.find_each do |user|
      user.medications.active.includes(:schedules).find_each do |medication|
        medication.schedules.active.each do |schedule|
          next unless schedule.active_on?(date)

          scheduled_for = DateTime.new(
            date.year,
            date.month,
            date.day,
            schedule.time_of_day.hour,
            schedule.time_of_day.min,
            0,
            Time.zone.formatted_offset
          )

          Dose.find_or_create_by!(
            schedule: schedule,
            medication: medication,
            scheduled_for: scheduled_for
          )
        end
      end
    end
  end
end