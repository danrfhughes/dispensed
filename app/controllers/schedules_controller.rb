class SchedulesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_medication
  before_action :set_schedule, only: [:edit, :update, :destroy]

  def new
    @schedule = @medication.schedules.build(time_of_day: "08:00")
  end

  def create
    normalize_days_param
    @schedule = @medication.schedules.build(schedule_params)
    if @schedule.save
      redirect_to medication_path(@medication), notice: "Schedule added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    normalize_days_param
    if @schedule.update(schedule_params)
      redirect_to medication_path(@medication), notice: "Schedule updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @schedule.archive!
    redirect_to medication_path(@medication), notice: "Schedule removed."
  end

  private

  def set_medication
    @medication = current_user.patient_profile.medications.find(params[:medication_id])
  end

  def set_schedule
    @schedule = @medication.schedules.find(params[:id])
  end

  def normalize_days_param
    return unless params[:schedule]
    if params[:schedule][:days_of_week] != "daily" && params[:schedule][:days_of_week_multi].present?
      params[:schedule][:days_of_week] = Array(params[:schedule][:days_of_week_multi]).join(",")
    end
  end

  def schedule_params
    params.require(:schedule).permit(:time_of_day, :days_of_week, :instructions)
  end
end
