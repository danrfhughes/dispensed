class DosesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_dose

  def take
    @dose.take!
    redirect_back fallback_location: dashboard_path, notice: "Marked as taken."
  end

  def skip
    @dose.skip!
    redirect_back fallback_location: dashboard_path, notice: "Dose skipped."
  end

  private

  def set_dose
    @dose = Dose.joins(medication: :patient_profile).where(patient_profiles: { user_id: current_user.id }).find(params[:id])
  end
end