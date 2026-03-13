require "rails_helper"

RSpec.describe NhsApi::PdsMock do
  subject(:mock) { described_class.new }

  describe "#fetch_patient" do
    it "returns demographics for a known NHS number" do
      data = mock.fetch_patient("9876543210")

      expect(data[:first_name]).to eq("Jane")
      expect(data[:last_name]).to eq("Smith")
      expect(data[:date_of_birth]).to eq("1955-03-15")
      expect(data[:gender]).to eq("female")
      expect(data[:postcode]).to eq("LS1 6AE")
      expect(data[:gp_ods_code]).to eq("B81001")
      expect(data[:nominated_pharmacy_ods]).to eq("FLM49")
    end

    it "raises NotFound for an unknown NHS number" do
      expect {
        mock.fetch_patient("0000000000")
      }.to raise_error(NhsApi::PdsClient::NotFound)
    end

    it "ignores access_token parameter" do
      data = mock.fetch_patient("9876543210", access_token: "fake-token")
      expect(data[:first_name]).to eq("Jane")
    end
  end
end
