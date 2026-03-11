require 'rails_helper'

RSpec.describe PatientProfile, type: :model do
  it { should belong_to(:user) }

  describe 'nhs_number validation' do
    it 'accepts a valid 10-digit NHS number' do
      profile = build(:patient_profile, nhs_number: "9434765919")
      expect(profile).to be_valid
    end

    it 'rejects a non-10-digit NHS number' do
      profile = build(:patient_profile, nhs_number: "123")
      expect(profile).not_to be_valid
    end

    it 'accepts a blank NHS number' do
      profile = build(:patient_profile, nhs_number: nil)
      expect(profile).to be_valid
    end
  end

  describe '#display_nhs_number' do
    it 'formats the NHS number with spaces' do
      profile = build(:patient_profile, nhs_number: "9434765919")
      expect(profile.display_nhs_number).to eq("943 476 5919")
    end
  end
end