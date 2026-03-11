require 'rails_helper'

RSpec.describe Dose, type: :model do
  it { should belong_to(:medication) }
  it { should belong_to(:schedule) }
  it { should validate_presence_of(:scheduled_for) }
  it { should validate_inclusion_of(:status).in_array(Dose::STATUSES) }

  describe '#take!' do
    it 'marks the dose as taken and sets taken_at' do
      dose = create(:dose)
      dose.take!
      expect(dose.status).to eq("taken")
      expect(dose.taken_at).to be_present
    end
  end

  describe '#skip!' do
    it 'marks the dose as skipped' do
      dose = create(:dose)
      dose.skip!
      expect(dose.status).to eq("skipped")
    end
  end

  describe '#mark_missed!' do
    it 'marks the dose as missed' do
      dose = create(:dose)
      dose.mark_missed!
      expect(dose.status).to eq("missed")
    end
  end

  describe '.for_date' do
    it 'returns doses scheduled for the given date' do
      date = Date.new(2026, 3, 11)
      today_dose = create(:dose, scheduled_for: date.beginning_of_day + 8.hours)
      yesterday_dose = create(:dose, scheduled_for: (date - 1.day).beginning_of_day + 8.hours)
      expect(Dose.for_date(date)).to include(today_dose)
      expect(Dose.for_date(date)).not_to include(yesterday_dose)
    end
  end
end