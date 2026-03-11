class MedicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_medication, only: [:show, :edit, :update, :destroy]

  def index
    @medications = current_user.patient_profile.medications.active.order(:name)
    @archived = current_user.patient_profile.medications.archived.order(:name)
  end

  def show
  end

  def new
    @medication = current_user.patient_profile.medications.build
  end

  def create
    @medication = current_user.patient_profile.medications.build(medication_params)
    if @medication.save
      redirect_to medications_path, notice: "Medication added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @medication.update(medication_params)
      redirect_to medications_path, notice: "Medication updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @medication.archive!
    redirect_to medications_path, notice: "Medication archived."
  end

  private

  def set_medication
    @medication = current_user.patient_profile.medications.find(params[:id])
  end

  def medication_params
    params.require(:medication).permit(:name, :dose, :form, :notes, :start_date, :end_date, :days_supply, :last_dispensed_on, :active)
  end
end