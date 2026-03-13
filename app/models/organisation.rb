class Organisation < ApplicationRecord
  TYPES = %w[gp_practice pharmacy trust icb].freeze

  has_many :gp_patients, class_name: "PatientProfile", foreign_key: :gp_organisation_id, inverse_of: :gp_practice, dependent: :nullify
  has_many :pharmacy_patients, class_name: "PatientProfile", foreign_key: :nominated_pharmacy_id, inverse_of: :nominated_pharmacy, dependent: :nullify

  validates :ods_code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :organisation_type, inclusion: { in: TYPES }, allow_blank: true

  scope :gp_practices, -> { where(organisation_type: "gp_practice") }
  scope :pharmacies, -> { where(organisation_type: "pharmacy") }
  scope :active, -> { where(active: true) }

  def display_name
    "#{name} (#{ods_code})"
  end
end
