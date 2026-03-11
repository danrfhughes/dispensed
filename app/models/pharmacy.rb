class Pharmacy < ApplicationRecord
  belongs_to :patient_profile

  validates :name, presence: true
end
