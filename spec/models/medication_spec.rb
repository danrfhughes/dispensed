require 'rails_helper'

RSpec.describe Medication, type: :model do
  it { should belong_to(:patient_profile) }
  it { should validate_presence_of(:name) }
  it { should validate_numericality_of(:days_supply).is_greater_than(0) }

  describe '#days_until_reorder' do
    let(:med) { build(:medication, last_dispensed_on: Date.today, days_supply: 28) }

    it 'returns days until reorder threshold (5 days before end of supply)' do
      expect(med.days_until_reorder).to eq(23)
    end
  end

  describe '#needs_reorder?' do
    it 'returns true when reorder date has passed' do
      med = build(:medication, last_dispensed_on: 30.days.ago, days_supply: 28)
      expect(med.needs_reorder?).to be true
    end

    it 'returns false when supply is sufficient' do
      med = build(:medication, last_dispensed_on: Date.today, days_supply: 28)
      expect(med.needs_reorder?).to be false
    end
  end
end