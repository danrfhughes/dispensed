class Medication < ApplicationRecord
  belongs_to :patient_profile
  delegate :user, to: :patient_profile
  has_many :schedules, dependent: :destroy
  has_many :doses, dependent: :destroy

  validates :name, presence: true
  validates :days_supply, numericality: { greater_than: 0 }

  scope :active, -> { where(active: true) }
  scope :archived, -> { where(active: false) }

  def archive!
    update!(active: false)
  end

  def days_until_reorder
    return nil unless last_dispensed_on && days_supply
    reorder_date = last_dispensed_on + days_supply.days - 5.days
    (reorder_date - Date.today).to_i
  end

  def needs_reorder?
    days_until_reorder && days_until_reorder <= 0
  end

  def days_until_supply_ends
    return nil unless last_dispensed_on && days_supply
    (last_dispensed_on + days_supply.days - Date.today).to_i
  end
end