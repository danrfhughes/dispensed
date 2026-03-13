require "rails_helper"

RSpec.describe NhsApi::DemographicsSync do
  let(:user) { create(:user) }
  let(:profile) { user.patient_profile }

  before do
    profile.update!(
      nhs_number: "9876543210",
      nhs_login_identity_level: "P5"
    )
  end

  describe ".call" do
    it "populates demographics from PDS mock" do
      described_class.call(profile)

      profile.reload
      expect(profile.first_name).to eq("Jane")
      expect(profile.last_name).to eq("Smith")
      expect(profile.gender).to eq("female")
      expect(profile.postcode).to eq("LS1 6AE")
      expect(profile.phone).to eq("07700900000")
      expect(profile.demographics_fetched_at).to be_present
    end

    it "creates GP practice organisation" do
      expect { described_class.call(profile) }.to change { Organisation.gp_practices.count }.by(1)

      gp = Organisation.find_by(ods_code: "B81001")
      expect(gp.name).to eq("The Limes Medical Centre")
      expect(gp.organisation_type).to eq("gp_practice")
    end

    it "creates nominated pharmacy organisation" do
      expect { described_class.call(profile) }.to change { Organisation.pharmacies.count }.by(1)

      pharmacy = Organisation.find_by(ods_code: "FLM49")
      expect(pharmacy.organisation_type).to eq("pharmacy")
    end

    it "links GP and pharmacy to patient profile" do
      described_class.call(profile)
      profile.reload

      expect(profile.gp_practice.ods_code).to eq("B81001")
      expect(profile.nominated_pharmacy.ods_code).to eq("FLM49")
    end

    it "reuses existing organisation records" do
      create(:organisation, ods_code: "B81001", name: "Existing GP", organisation_type: "gp_practice")

      expect { described_class.call(profile) }.to change { Organisation.count }.by(1) # only pharmacy created

      profile.reload
      expect(profile.gp_practice.name).to eq("Existing GP")
    end

    it "skips sync for P0 identity level" do
      profile.update!(nhs_login_identity_level: "P0")

      described_class.call(profile)
      profile.reload

      expect(profile.first_name).to be_nil
      expect(profile.demographics_fetched_at).to be_nil
    end

    it "skips sync when nhs_number is blank" do
      profile.update!(nhs_number: nil)

      described_class.call(profile)
      profile.reload

      expect(profile.first_name).to be_nil
    end

    it "skips sync when demographics were recently fetched" do
      profile.update!(demographics_fetched_at: 1.hour.ago)

      described_class.call(profile)
      profile.reload

      expect(profile.first_name).to be_nil # not updated because not stale
    end

    it "re-syncs when demographics are stale (>24h)" do
      profile.update!(demographics_fetched_at: 25.hours.ago)

      described_class.call(profile)
      profile.reload

      expect(profile.first_name).to eq("Jane")
    end

    it "handles PDS NotFound gracefully" do
      profile.update!(nhs_number: "0000000000")

      expect { described_class.call(profile) }.not_to raise_error

      profile.reload
      expect(profile.first_name).to be_nil
    end
  end
end
