class PharmaciesController < ApplicationController
  before_action :authenticate_user!

  def show
    @pharmacy = current_user.patient_profile.pharmacy
    redirect_to new_pharmacy_path unless @pharmacy
  end

  def new
    @pharmacy = current_user.patient_profile.build_pharmacy
  end

  def create
    @pharmacy = current_user.patient_profile.build_pharmacy(pharmacy_params)
    if @pharmacy.save
      redirect_to pharmacy_path, notice: "Pharmacy saved."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @pharmacy = current_user.patient_profile.pharmacy
    redirect_to new_pharmacy_path unless @pharmacy
  end

  def update
    @pharmacy = current_user.patient_profile.pharmacy
    if @pharmacy.update(pharmacy_params)
      redirect_to pharmacy_path, notice: "Pharmacy updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def pharmacy_params
    params.require(:pharmacy).permit(:name, :address, :phone, :email)
  end
end
