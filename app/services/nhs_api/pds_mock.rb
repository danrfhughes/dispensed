# frozen_string_literal: true

module NhsApi
  # Mock PDS client for development and test environments.
  # Returns canned demographics for known NHS numbers.
  class PdsMock
    PATIENTS = {
      "9876543210" => {
        first_name: "Jane",
        last_name: "Smith",
        date_of_birth: "1955-03-15",
        gender: "female",
        address_line_1: "1 Trevelyan Square",
        address_line_2: "Boar Lane",
        city: "Leeds",
        postcode: "LS1 6AE",
        phone: "07700900000",
        gp_ods_code: "B81001",
        gp_name: "The Limes Medical Centre",
        nominated_pharmacy_ods: "FLM49"
      },
      "9434765919" => {
        first_name: "John",
        last_name: "Doe",
        date_of_birth: "1980-07-22",
        gender: "male",
        address_line_1: "42 High Street",
        address_line_2: nil,
        city: "Manchester",
        postcode: "M1 1AA",
        phone: "07700900001",
        gp_ods_code: "P84012",
        gp_name: "Parkside Medical Practice",
        nominated_pharmacy_ods: "FA123"
      }
    }.freeze

    def fetch_patient(nhs_number, access_token: nil)
      data = PATIENTS[nhs_number]
      raise NhsApi::PdsClient::NotFound, "PDS mock: patient #{nhs_number} not found" unless data

      data.dup
    end
  end
end
