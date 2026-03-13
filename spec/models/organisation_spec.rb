require "rails_helper"

RSpec.describe Organisation, type: :model do
  describe "validations" do
    it "is valid with required attributes" do
      org = build(:organisation)
      expect(org).to be_valid
    end

    it "requires ods_code" do
      org = build(:organisation, ods_code: nil)
      expect(org).not_to be_valid
    end

    it "requires name" do
      org = build(:organisation, name: nil)
      expect(org).not_to be_valid
    end

    it "enforces unique ods_code" do
      create(:organisation, ods_code: "B81001")
      org = build(:organisation, ods_code: "B81001")
      expect(org).not_to be_valid
    end

    it "validates organisation_type inclusion" do
      org = build(:organisation, organisation_type: "invalid_type")
      expect(org).not_to be_valid
    end

    it "allows blank organisation_type" do
      org = build(:organisation, organisation_type: nil)
      expect(org).to be_valid
    end
  end

  describe "scopes" do
    let!(:gp) { create(:organisation, :gp_practice) }
    let!(:pharmacy) { create(:organisation, :pharmacy) }
    let!(:inactive) { create(:organisation, organisation_type: "trust", active: false) }

    it ".gp_practices returns only GP practices" do
      expect(Organisation.gp_practices).to contain_exactly(gp)
    end

    it ".pharmacies returns only pharmacies" do
      expect(Organisation.pharmacies).to contain_exactly(pharmacy)
    end

    it ".active returns only active organisations" do
      expect(Organisation.active).to contain_exactly(gp, pharmacy)
    end
  end

  describe "#display_name" do
    it "combines name and ODS code" do
      org = build(:organisation, name: "Test Practice", ods_code: "B81001")
      expect(org.display_name).to eq("Test Practice (B81001)")
    end
  end
end
