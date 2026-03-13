require "rails_helper"

RSpec.describe NhsApi::PdsClient do
  describe ".for_environment" do
    it "returns a PdsMock in test environment" do
      client = described_class.for_environment
      expect(client).to be_a(NhsApi::PdsMock)
    end
  end

  describe "#parse_patient (via private method)" do
    subject(:client) { described_class.new }

    let(:fhir_patient) do
      {
        "name" => [
          {
            "use" => "usual",
            "family" => "Smith",
            "given" => ["Jane"]
          }
        ],
        "birthDate" => "1955-03-15",
        "gender" => "female",
        "address" => [
          {
            "use" => "home",
            "line" => ["1 Trevelyan Square", "Boar Lane"],
            "city" => "Leeds",
            "postalCode" => "LS1 6AE"
          }
        ],
        "telecom" => [
          { "system" => "phone", "value" => "07700900000" }
        ],
        "generalPractitioner" => [
          {
            "identifier" => { "value" => "B81001" },
            "display" => "The Limes Medical Centre"
          }
        ],
        "extension" => [
          {
            "url" => "https://fhir.nhs.uk/StructureDefinition/Extension-PDS-nominatedPharmacy",
            "valueReference" => {
              "identifier" => { "value" => "FLM49" }
            }
          }
        ]
      }
    end

    it "parses a FHIR Patient resource correctly" do
      result = client.send(:parse_patient, fhir_patient)

      expect(result[:first_name]).to eq("Jane")
      expect(result[:last_name]).to eq("Smith")
      expect(result[:date_of_birth]).to eq("1955-03-15")
      expect(result[:gender]).to eq("female")
      expect(result[:address_line_1]).to eq("1 Trevelyan Square")
      expect(result[:address_line_2]).to eq("Boar Lane")
      expect(result[:city]).to eq("Leeds")
      expect(result[:postcode]).to eq("LS1 6AE")
      expect(result[:phone]).to eq("07700900000")
      expect(result[:gp_ods_code]).to eq("B81001")
      expect(result[:gp_name]).to eq("The Limes Medical Centre")
      expect(result[:nominated_pharmacy_ods]).to eq("FLM49")
    end

    it "handles missing fields gracefully" do
      result = client.send(:parse_patient, {})

      expect(result[:first_name]).to be_nil
      expect(result[:last_name]).to be_nil
      expect(result[:gp_ods_code]).to be_nil
      expect(result[:nominated_pharmacy_ods]).to be_nil
    end
  end
end
