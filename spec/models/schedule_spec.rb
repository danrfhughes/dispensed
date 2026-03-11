require 'rails_helper'

RSpec.describe Schedule, type: :model do
  before { allow_any_instance_of(GenerateDailyDosesJob).to receive(:perform) }

  it { should belong_to(:medication) }
  it { should validate_presence_of(:time_of_day) }
  it { should validate_presence_of(:days_of_week) }

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
