class Schedule < ApplicationRecord
  belongs_to :medication
  has_many :doses, dependent: :destroy

  DAYS = %w[monday tuesday wednesday thursday friday saturday sunday daily].freeze

  ROUTINE_ANCHORS = {
    "waking"       => { label: "When you wake up",       default_time: "07:00", window_minutes: 120 },
    "breakfast"    => { label: "With breakfast",          default_time: "08:00", window_minutes: 120 },
    "midday"       => { label: "Around midday",          default_time: "12:00", window_minutes: 120 },
    "evening_meal" => { label: "With your evening meal", default_time: "18:00", window_minutes: 120 },
    "bedtime"      => { label: "Before bed",             default_time: "22:00", window_minutes: 90  },
  }.freeze

  FOOD_RELATIONS = %w[with_food before_food after_food empty_stomach].freeze

  validates :time_of_day, presence: true, unless: -> { routine_anchor.present? }
  validates :days_of_week, presence: true
  validates :routine_anchor, inclusion: { in: ROUTINE_ANCHORS.keys }, allow_nil: true
  validates :food_relation, inclusion: { in: FOOD_RELATIONS }, allow_blank: true
  validate :no_overlapping_schedules

  before_validation :apply_anchor_default_time

  scope :active, -> { where(active: true) }

  after_create :generate_todays_dose
  after_update :regenerate_doses_from_today

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

  def routine_anchor?
    routine_anchor.present?
  end

  def routine_label
    return nil unless routine_anchor?
    ROUTINE_ANCHORS.dig(routine_anchor, :label)
  end

  def food_relation_label
    return nil unless food_relation.present?
    food_relation.tr("_", " ")
  end

  def window_minutes
    routine_anchor? ? ROUTINE_ANCHORS.dig(routine_anchor, :window_minutes) : 60
  end

  private

  def apply_anchor_default_time
    return unless routine_anchor.present? && time_of_day.blank?
    default = ROUTINE_ANCHORS.dig(routine_anchor, :default_time)
    self.time_of_day = Time.zone.parse(default) if default
  end

  def generate_todays_dose
    GenerateDailyDosesJob.new.perform(Date.current)
  end

  def regenerate_doses_from_today
    return unless saved_change_to_time_of_day? || saved_change_to_days_of_week? || saved_change_to_routine_anchor?

    doses.where(status: "pending")
         .where("scheduled_for >= ?", Time.current.beginning_of_day)
         .destroy_all

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
