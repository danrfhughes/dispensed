class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @medications = current_user.patient_profile.medications.active
                               .includes(:schedules)
                               .order(:name)

    @week_days = (0..6).map { |i| Date.current.beginning_of_week + i }

    @week_doses = Dose
      .joins(medication: :patient_profile)
      .where(patient_profiles: { user_id: current_user.id })
      .where(scheduled_for: @week_days.first.beginning_of_day..@week_days.last.end_of_day)
      .group_by { |d| [d.medication_id, d.scheduled_for.to_date] }

    @medications_needing_reorder = current_user.patient_profile.medications.active
                                               .select(&:needs_reorder?)

    @prescriptions_expiring = @medications
      .map { |m| { med: m, days: m.days_until_supply_ends } }
      .select { |p| p[:days].present? }
      .sort_by { |p| p[:days] }
  end
end
