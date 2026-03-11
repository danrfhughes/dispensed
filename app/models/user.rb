class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_one :patient_profile, dependent: :destroy
  has_many :medications, through: :patient_profile

  ROLES = %w[patient admin].freeze

  def admin?
    role == "admin"
  end

  def patient?
    role == "patient"
  end

  after_create :create_patient_profile

  private

  def create_patient_profile
    PatientProfile.find_or_create_by!(user: self)
  end
end