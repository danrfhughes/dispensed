class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:nhslogin]

  has_one :patient_profile, dependent: :destroy
  has_many :medications, through: :patient_profile

  ROLES = %w[patient admin].freeze

  def admin?
    role == "admin"
  end

  def patient?
    role == "patient"
  end

  # Find or create a user from an OmniAuth auth hash.
  # Called from Users::OmniauthCallbacksController.
  def self.from_omniauth(auth)
    find_or_initialize_by(provider: auth.provider, uid: auth.uid).tap do |user|
      user.email = auth.info.email if user.email.blank? && auth.info.email.present?
      user.save! if user.new_record?
    end
  end

  # NHS Login users don't have a password — skip Devise's password validation
  def password_required?
    provider.blank? && super
  end

  after_create :create_patient_profile

  private

  def create_patient_profile
    PatientProfile.find_or_create_by!(user: self)
  end
end