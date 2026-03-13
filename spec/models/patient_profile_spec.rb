require "rails_helper"

RSpec.describe PatientProfile, type: :model do
  it { should belong_to(:user) }

  describe "nhs_number validation" do
    it "accepts a valid 10-digit NHS number" do
      profile = build(:patient_profile, nhs_number: "9434765919")
      expect(profile).to be_valid
    end

    it "rejects a non-10-digit NHS number" do
      profile = build(:patient_profile, nhs_number: "123")
      expect(profile).not_to be_valid
    end

    it "accepts a blank NHS number" do
      profile = build(:patient_profile, nhs_number: nil)
      expect(profile).to be_valid
    end
  end

  describe "#display_nhs_number" do
    it "formats the NHS number with spaces" do
      profile = build(:patient_profile, nhs_number: "9434765919")
      expect(profile.display_nhs_number).to eq("943 476 5919")
    end
  end

  describe "#full_name" do
    it "combines first and last name" do
      profile = build(:patient_profile, first_name: "Jane", last_name: "Smith")
      expect(profile.full_name).to eq("Jane Smith")
    end

    it "returns nil when both are blank" do
      profile = build(:patient_profile, first_name: nil, last_name: nil)
      expect(profile.full_name).to be_nil
    end
  end

  describe "#demographics_stale?" do
    it "returns true when never fetched" do
      profile = build(:patient_profile, demographics_fetched_at: nil)
      expect(profile.demographics_stale?).to be true
    end

    it "returns false when recently fetched" do
      profile = build(:patient_profile, demographics_fetched_at: 1.hour.ago)
      expect(profile.demographics_stale?).to be false
    end

    it "returns true when fetched over 24 hours ago" do
      profile = build(:patient_profile, demographics_fetched_at: 25.hours.ago)
      expect(profile.demographics_stale?).to be true
    end
  end

  describe "organisation associations" do
    it "can belong to a GP practice" do
      gp = create(:organisation, :gp_practice)
      user = create(:user)
      profile = user.patient_profile
      profile.update!(gp_practice: gp)
      expect(profile.reload.gp_practice).to eq(gp)
    end

    it "can belong to a nominated pharmacy" do
      pharmacy = create(:organisation, :pharmacy)
      user = create(:user)
      profile = user.patient_profile
      profile.update!(nominated_pharmacy: pharmacy)
      expect(profile.reload.nominated_pharmacy).to eq(pharmacy)
    end
  end
end
