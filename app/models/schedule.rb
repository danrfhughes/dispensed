class Schedule < ApplicationRecord
  belongs_to :medication
  has_many :doses, dependent: :destroy

  validates :time_of_day, presence: true
  validates :days_of_week, presence: true
  validate :no_overlapping_schedules

  scope :active, -> { where(active: true) }

  DAYS = %w[monday tuesday wednesday thursday friday saturday sunday daily].freeze

  def days_label
    return "Daily" if days_of_week == "daily"
    days_of_week.split(",").map(&:capitalize).join(", ")
  end

  def active_on?(date)
    return true if days_of_week == "daily"
    days_of_week.split(",").include?(date.strftime("%A").downcase)
  end

  def archive!
    update!(active: false)
  end

  after_create :generate_todays_dose

  private

  def generate_todays_dose
    GenerateDailyDosesJob.new.perform(Date.current)
  end

  def no_overlapping_schedules
    return unless active? && medication.present?
    siblings = medication.schedules.active.where.not(id: id)
    return if siblings.none?

    if days_of_week == "daily"
      errors.add(:days_of_week, "conflicts with an existing schedule — remove it first before adding a Daily one")
    elsif siblings.any? { |s| s.days_of_week == "daily" }
      errors.add(:days_of_week, "conflicts with an existing Daily schedule")
    else
      existing_days = siblings.flat_map { |s| s.days_of_week.split(",") }.uniq
      overlap = days_of_week.to_s.split(",") & existing_days
      if overlap.any?
        errors.add(:days_of_week, "conflicts with an existing schedule on #{overlap.map(&:capitalize).join(", ")}")
      end
    end
  end
end