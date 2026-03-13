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

  before_validation :normalize_routine_anchor
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

  def normalize_routine_anchor
    self.routine_anchor = nil if routine_anchor.blank?
  end

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

    # Only block if a sibling has the same time slot on an overlapping day.
    # "Same time slot" means same routine_anchor, or same time_of_day (within 2 hours) when no anchors.
    siblings.each do |sibling|
      next unless days_overlap?(sibling)
      next unless same_time_slot?(sibling)

      if routine_anchor.present?
        errors.add(:routine_anchor, "already has a #{ROUTINE_ANCHORS.dig(routine_anchor, :label)} schedule")
      else
        errors.add(:time_of_day, "conflicts with an existing schedule at the same time")
      end
      return
    end
  end

  def days_overlap?(other)
    my_days = expand_days(days_of_week)
    other_days = expand_days(other.days_of_week)
    (my_days & other_days).any?
  end

  def expand_days(dow)
    return Schedule::DAYS.reject { |d| d == "daily" } if dow == "daily"
    dow.to_s.split(",")
  end

  def same_time_slot?(other)
    # Both have routine anchors — conflict if same anchor
    if routine_anchor.present? && other.routine_anchor.present?
      return routine_anchor == other.routine_anchor
    end

    # Compare times — conflict if within 2 hours
    return false unless time_of_day.present? && other.time_of_day.present?

    gap = (time_of_day.seconds_since_midnight - other.time_of_day.seconds_since_midnight).abs
    gap < 2.hours.to_i
  end
end
