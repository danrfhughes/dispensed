class AdherenceController < ApplicationController
  before_action :authenticate_user!

  def index
    @medications = current_user.patient_profile.medications.active.order(:name)
    @stats = @medications.map do |med|
      {
        medication: med,
        seven_day:  adherence_stats(med, 7),
        twenty_eight_day: adherence_stats(med, 28)
      }
    end
  end

  private

  def adherence_stats(medication, days)
    doses = medication.doses.where(
      scheduled_for: days.days.ago.beginning_of_day..Time.current
    )
    scheduled   = doses.count
    taken_doses = doses.taken.to_a
    taken       = taken_doses.count
    on_time     = taken_doses.count { |d| (d.taken_at - d.scheduled_for).abs <= 3600 }
    {
      scheduled:        scheduled,
      taken:            taken,
      on_time:          on_time,
      percentage:       scheduled > 0 ? ((taken.to_f / scheduled) * 100).round : nil,
      on_time_percentage: taken > 0 ? ((on_time.to_f / taken) * 100).round : nil
    }
  end
end