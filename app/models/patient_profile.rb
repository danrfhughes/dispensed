class PatientProfile < ApplicationRecord
  belongs_to :user
  has_many :medications, dependent: :destroy

  validates :nhs_number, format: { with: /\A\d{10}\z/, message: "must be 10 digits" }, allow_blank: true
  validates :nhs_number, uniqueness: true, allow_blank: true

  def display_nhs_number
    return nil unless nhs_number
    "#{nhs_number[0..2]} #{nhs_number[3..5]} #{nhs_number[6..9]}"
  end
end