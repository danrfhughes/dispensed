class SchedulesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_medication
  before_action :set_schedule, only: [:edit, :update, :destroy]

  def new
    @schedule = @medication.schedules.build
  end

  def create
    normalize_days_param

    if params[:schedule][:frequency_type] == "twice_daily"
      create_twice_daily
    else
      @schedule = @medication.schedules.build(schedule_params)
      if @schedule.save
        redirect_to medication_path(@medication), notice: "Schedule added."
      else
        render :new, status: :unprocessable_entity
      end
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
    params.require(:schedule).permit(:time_of_day, :days_of_week, :instructions, :routine_anchor, :food_relation)
  end

  def create_twice_daily
    days = params[:schedule][:days_of_week] || "daily"
    instructions = params[:schedule][:instructions]

    morning_attrs = {
      routine_anchor: params[:schedule][:morning_anchor].presence,
      food_relation: params[:schedule][:morning_food_relation].presence,
      time_of_day: params[:schedule][:morning_time_of_day].presence,
      days_of_week: days,
      instructions: instructions
    }

    evening_attrs = {
      routine_anchor: params[:schedule][:evening_anchor].presence,
      food_relation: params[:schedule][:evening_food_relation].presence,
      time_of_day: params[:schedule][:evening_time_of_day].presence,
      days_of_week: days,
      instructions: instructions
    }

    morning = @medication.schedules.build(morning_attrs)
    evening = @medication.schedules.build(evening_attrs)

    ActiveRecord::Base.transaction do
      morning.save!
      evening.save!
    end

    redirect_to medication_path(@medication), notice: "Twice-daily schedule added."
  rescue ActiveRecord::RecordInvalid
    @schedule = @medication.schedules.build
    @twice_daily_errors = (morning.errors.full_messages + evening.errors.full_messages).uniq
    render :new, status: :unprocessable_entity
  end
end
