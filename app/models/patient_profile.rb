class PatientProfile < ApplicationRecord
  belongs_to :user
  has_many :medications, dependent: :destroy
  belongs_to :gp_practice, class_name: "Organisation", foreign_key: :gp_organisation_id, optional: true, inverse_of: :gp_patients
  belongs_to :nominated_pharmacy, class_name: "Organisation", foreign_key: :nominated_pharmacy_id, optional: true, inverse_of: :pharmacy_patients

  validates :nhs_number, format: { with: /\A\d{10}\z/, message: "must be 10 digits" }, allow_blank: true
  validates :nhs_number, uniqueness: true, allow_blank: true

  def display_nhs_number
    return nil unless nhs_number
    "#{nhs_number[0..2]} #{nhs_number[3..5]} #{nhs_number[6..9]}"
  end

  def full_name
    [first_name, last_name].compact_blank.join(" ").presence
  end

  def full_address
    [address_line_1, address_line_2, city, postcode].compact_blank.join(", ").presence
  end

  def demographics_stale?
    demographics_fetched_at.nil? || demographics_fetched_at < 24.hours.ago
  end
end