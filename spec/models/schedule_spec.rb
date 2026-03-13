require 'rails_helper'

RSpec.describe Schedule, type: :model do
  before { allow_any_instance_of(GenerateDailyDosesJob).to receive(:perform) }

  it { should belong_to(:medication) }
  it { should validate_presence_of(:days_of_week) }

  describe 'time_of_day validation' do
    it 'requires time_of_day when no routine anchor is set' do
      schedule = build(:schedule, time_of_day: nil, routine_anchor: nil)
      expect(schedule).not_to be_valid
      expect(schedule.errors[:time_of_day]).to be_present
    end

    it 'does not require time_of_day when routine anchor is set' do
      schedule = build(:schedule, :routine)
      expect(schedule).to be_valid
    end
  end

  describe 'routine_anchor validation' do
    it 'accepts valid anchor values' do
      Schedule::ROUTINE_ANCHORS.each_key do |anchor|
        expect(build(:schedule, routine_anchor: anchor, time_of_day: nil)).to be_valid
      end
    end

    it 'rejects invalid anchor values' do
      schedule = build(:schedule, routine_anchor: "lunch", time_of_day: nil)
      expect(schedule).not_to be_valid
      expect(schedule.errors[:routine_anchor]).to be_present
    end

    it 'allows nil' do
      expect(build(:schedule, routine_anchor: nil)).to be_valid
    end
  end

  describe 'food_relation validation' do
    it 'accepts valid food relation values' do
      Schedule::FOOD_RELATIONS.each do |relation|
        expect(build(:schedule, food_relation: relation)).to be_valid
      end
    end

    it 'rejects invalid values' do
      schedule = build(:schedule, food_relation: "during_food")
      expect(schedule).not_to be_valid
      expect(schedule.errors[:food_relation]).to be_present
    end

    it 'allows nil' do
      expect(build(:schedule, food_relation: nil)).to be_valid
    end
  end

  describe 'apply_anchor_default_time' do
    it 'fills time_of_day from anchor default when blank' do
      schedule = create(:schedule, :routine)
      expect(schedule.time_of_day.strftime("%H:%M")).to eq("08:00")
    end

    it 'preserves explicit time_of_day when set with anchor' do
      schedule = create(:schedule, routine_anchor: "breakfast", time_of_day: "09:30")
      expect(schedule.time_of_day.strftime("%H:%M")).to eq("09:30")
    end

    it 'does not modify time_of_day for clock-time schedules' do
      schedule = create(:schedule, time_of_day: "14:00")
      expect(schedule.time_of_day.strftime("%H:%M")).to eq("14:00")
    end
  end

  describe '#routine_anchor?' do
    it 'returns true when routine_anchor is set' do
      expect(build(:schedule, :routine).routine_anchor?).to be true
    end

    it 'returns false when routine_anchor is nil' do
      expect(build(:schedule).routine_anchor?).to be false
    end
  end

  describe '#routine_label' do
    it 'returns the anchor label' do
      expect(build(:schedule, routine_anchor: "breakfast").routine_label).to eq("With breakfast")
    end

    it 'returns nil for clock-time schedules' do
      expect(build(:schedule).routine_label).to be_nil
    end
  end

  describe '#food_relation_label' do
    it 'humanises the food relation' do
      expect(build(:schedule, food_relation: "with_food").food_relation_label).to eq("with food")
      expect(build(:schedule, food_relation: "empty_stomach").food_relation_label).to eq("empty stomach")
    end

    it 'returns nil when no food relation is set' do
      expect(build(:schedule).food_relation_label).to be_nil
    end
  end

  describe '#window_minutes' do
    it 'returns the anchor window for routine schedules' do
      expect(build(:schedule, routine_anchor: "breakfast").window_minutes).to eq(120)
      expect(build(:schedule, routine_anchor: "bedtime").window_minutes).to eq(90)
    end

    it 'returns 60 for clock-time schedules' do
      expect(build(:schedule).window_minutes).to eq(60)
    end
  end

  describe '#active_on?' do
    let(:schedule) { build(:schedule, days_of_week: "daily") }

    it 'returns true for daily schedules on any day' do
      expect(schedule.active_on?(Date.today)).to be true
    end

    it 'returns true when the day matches' do
      monday = Date.parse("2026-03-09")
      schedule.days_of_week = "monday"
      expect(schedule.active_on?(monday)).to be true
    end

    it 'returns false when the day does not match' do
      monday = Date.parse("2026-03-09")
      schedule.days_of_week = "tuesday"
      expect(schedule.active_on?(monday)).to be false
    end
  end

  describe '#days_label' do
    it 'returns Daily for daily schedules' do
      expect(build(:schedule, days_of_week: "daily").days_label).to eq("Daily")
    end

    it 'returns formatted days for specific days' do
      expect(build(:schedule, days_of_week: "monday,wednesday").days_label).to eq("Monday, Wednesday")
    end
  end

  describe '#archive!' do
    it 'sets active to false' do
      schedule = create(:schedule)
      schedule.archive!
      expect(schedule.reload.active).to be false
    end

    it 'succeeds even when a conflicting active schedule exists' do
      medication = create(:medication)
      daily = create(:schedule, medication: medication, days_of_week: "daily")
      specific = Schedule.new(medication: medication, time_of_day: "08:00", days_of_week: "monday", active: false)
      specific.save(validate: false)

      expect { daily.archive! }.not_to raise_error
    end
  end

  describe 'regenerate_doses_from_today (SCHED-2)' do
    # Let the job run for real in these specs so regeneration actually creates doses
    before { allow_any_instance_of(GenerateDailyDosesJob).to receive(:perform).and_call_original }

    let(:medication) { create(:medication) }

    it 'regenerates pending dose when time_of_day changes' do
      schedule = create(:schedule, medication: medication, time_of_day: "08:00")
      # Manually create today's dose (simulating what the job does)
      dose = Dose.create!(schedule: schedule, medication: medication,
                          scheduled_for: Time.zone.today.change(hour: 8, min: 0))

      schedule.update!(time_of_day: "14:00")

      expect(Dose.where(schedule: schedule).count).to eq(1)
      expect(Dose.where(schedule: schedule).first.scheduled_for.hour).to eq(14)
    end

    it 'removes dose when schedule no longer active on today' do
      today_name = Date.current.strftime("%A").downcase
      schedule = create(:schedule, medication: medication, days_of_week: "daily")
      Dose.create!(schedule: schedule, medication: medication,
                   scheduled_for: Time.zone.today.change(hour: 8, min: 0))

      other_day = (Schedule::DAYS - ["daily", today_name]).first
      schedule.update!(days_of_week: other_day)

      expect(Dose.where(schedule: schedule).count).to eq(0)
    end

    it 'regenerates dose when routine_anchor changes' do
      schedule = create(:schedule, :routine, medication: medication)
      Dose.create!(schedule: schedule, medication: medication,
                   scheduled_for: Time.zone.today.change(hour: 8, min: 0))

      schedule.update!(routine_anchor: "bedtime", time_of_day: nil)

      doses = Dose.where(schedule: schedule)
      expect(doses.count).to eq(1)
      expect(doses.first.scheduled_for.hour).to eq(22)
    end

    it 'preserves taken doses when schedule is edited' do
      schedule = create(:schedule, medication: medication, time_of_day: "08:00")
      taken_dose = Dose.create!(schedule: schedule, medication: medication,
                                scheduled_for: Time.zone.today.change(hour: 8, min: 0),
                                status: "taken", taken_at: Time.current)

      schedule.update!(time_of_day: "14:00")

      expect(Dose.find(taken_dose.id).status).to eq("taken")
      all_doses = Dose.where(schedule: schedule).order(:scheduled_for)
      expect(all_doses.count).to eq(2)
      expect(all_doses.first.status).to eq("taken")
      expect(all_doses.last.status).to eq("pending")
      expect(all_doses.last.scheduled_for.hour).to eq(14)
    end

    it 'preserves skipped doses when schedule is edited' do
      schedule = create(:schedule, medication: medication, time_of_day: "08:00")
      Dose.create!(schedule: schedule, medication: medication,
                   scheduled_for: Time.zone.today.change(hour: 8, min: 0),
                   status: "skipped")

      schedule.update!(time_of_day: "14:00")

      statuses = Dose.where(schedule: schedule).pluck(:status)
      expect(statuses).to include("skipped")
    end

    it 'does not regenerate when only instructions change' do
      schedule = create(:schedule, medication: medication, time_of_day: "08:00")
      dose = Dose.create!(schedule: schedule, medication: medication,
                          scheduled_for: Time.zone.today.change(hour: 8, min: 0))

      expect { schedule.update!(instructions: "Take with water") }
        .not_to change { Dose.where(schedule: schedule).pluck(:id, :scheduled_for) }
    end

    it 'does not regenerate when only food_relation changes' do
      schedule = create(:schedule, :routine, medication: medication)
      Dose.create!(schedule: schedule, medication: medication,
                   scheduled_for: Time.zone.today.change(hour: 8, min: 0))

      expect { schedule.update!(food_relation: "empty_stomach") }
        .not_to change { Dose.where(schedule: schedule).pluck(:id, :scheduled_for) }
    end
  end

  describe 'no_overlapping_schedules validation' do
    let(:medication) { create(:medication) }

    context 'when no other schedules exist' do
      it 'allows a daily schedule' do
        expect(build(:schedule, medication: medication, days_of_week: "daily")).to be_valid
      end

      it 'allows a specific-day schedule' do
        expect(build(:schedule, medication: medication, days_of_week: "monday,wednesday")).to be_valid
      end
    end

    context 'when a daily schedule already exists' do
      before { create(:schedule, medication: medication, days_of_week: "daily") }

      it 'prevents adding another daily schedule' do
        duplicate = build(:schedule, medication: medication, days_of_week: "daily")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:days_of_week]).to be_present
      end

      it 'prevents adding a specific-day schedule' do
        specific = build(:schedule, medication: medication, days_of_week: "monday")
        expect(specific).not_to be_valid
        expect(specific.errors[:days_of_week]).to include(match(/Daily schedule/))
      end
    end

    context 'when a specific-day schedule already exists' do
      before { create(:schedule, medication: medication, days_of_week: "monday,wednesday") }

      it 'prevents adding a daily schedule' do
        daily = build(:schedule, medication: medication, days_of_week: "daily")
        expect(daily).not_to be_valid
        expect(daily.errors[:days_of_week]).to be_present
      end

      it 'prevents adding a schedule with overlapping days' do
        overlap = build(:schedule, medication: medication, days_of_week: "monday,friday")
        expect(overlap).not_to be_valid
        expect(overlap.errors[:days_of_week]).to include(match(/Monday/))
      end

      it 'allows adding a schedule with non-overlapping days' do
        no_overlap = build(:schedule, medication: medication, days_of_week: "thursday,friday")
        expect(no_overlap).to be_valid
      end
    end

    context 'when editing an existing schedule' do
      it 'does not conflict with itself' do
        schedule = create(:schedule, medication: medication, days_of_week: "daily")
        schedule.instructions = "Updated"
        expect(schedule).to be_valid
      end
    end

    context 'when a conflicting schedule is archived' do
      it 'allows adding a new schedule matching the archived days' do
        schedule = create(:schedule, medication: medication, days_of_week: "monday")
        schedule.update_column(:active, false)

        new_schedule = build(:schedule, medication: medication, days_of_week: "monday")
        expect(new_schedule).to be_valid
      end
    end
  end
end
