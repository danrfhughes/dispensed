class Dose < ApplicationRecord
  belongs_to :medication
  belongs_to :schedule

  STATUSES = %w[pending taken missed skipped].freeze

  validates :scheduled_for, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :for_date, ->(date) { where(scheduled_for: date.beginning_of_day..date.end_of_day) }
  scope :pending,  -> { where(status: "pending") }
  scope :taken,    -> { where(status: "taken") }
  scope :missed,   -> { where(status: "missed") }

  def take!
    update!(status: "taken", taken_at: Time.current)
  end

  def skip!
    update!(status: "skipped")
  end

  def mark_missed!
    update!(status: "missed")
  end
end