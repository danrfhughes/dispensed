class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @today_doses = Dose
      .joins(medication: :patient_profile)
      .where(patient_profiles: { user_id: current_user.id })
      .for_date(Date.current)
      .includes(:medication, :schedule)
      .order(:scheduled_for)

    @medications_needing_reorder = current_user.patient_profile.medications.active
      .select(&:needs_reorder?)
  end
end