# frozen_string_literal: true

require "net/http"
require "json"

module NhsApi
  # Fetches patient demographics from the NHS Personal Demographics Service (PDS) FHIR API.
  # https://digital.nhs.uk/developer/api-catalogue/personal-demographics-service-fhir
  #
  # Usage:
  #   client = NhsApi::PdsClient.for_environment
  #   data = client.fetch_patient("9876543210", access_token: token)
  class PdsClient
    BASE_URL = "https://api.service.nhs.uk/personal-demographics/FHIR/R4"

    class Error < StandardError; end
    class NotFound < Error; end
    class Unauthorized < Error; end

    def self.for_environment
      if Rails.env.test? || Rails.env.development?
        NhsApi::PdsMock.new
      else
        new
      end
    end

    def initialize(base_url: BASE_URL)
      @base_url = base_url
    end

    # Fetch patient demographics by NHS number.
    # Returns a structured hash or raises an error.
    def fetch_patient(nhs_number, access_token:)
      uri = URI("#{@base_url}/Patient/#{nhs_number}")

      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{access_token}"
      request["Accept"] = "application/fhir+json"
      request["X-Request-ID"] = SecureRandom.uuid

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      case response.code.to_i
      when 200
        parse_patient(JSON.parse(response.body))
      when 401
        raise Unauthorized, "PDS: invalid or expired access token"
      when 404
        raise NotFound, "PDS: patient #{nhs_number} not found"
      else
        raise Error, "PDS: unexpected response #{response.code}"
      end
    end

    private

    # Parse a FHIR Patient resource into a flat hash.
    def parse_patient(fhir)
      name = fhir.dig("name")&.find { |n| n["use"] == "usual" } || fhir.dig("name")&.first || {}
      address = fhir.dig("address")&.find { |a| a["use"] == "home" } || fhir.dig("address")&.first || {}
      phone = fhir.dig("telecom")&.find { |t| t["system"] == "phone" }

      gp = fhir.dig("generalPractitioner")&.first
      gp_ods = gp&.dig("identifier", "value")
      gp_name = gp&.dig("display")

      # Nominated pharmacy from the nhsCommunicationPharmacy extension
      pharmacy_ext = fhir.dig("extension")&.find { |e|
        e["url"]&.include?("nominatedPharmacy")
      }
      pharmacy_ods = pharmacy_ext&.dig("valueReference", "identifier", "value")

      {
        first_name: name.dig("given")&.first,
        last_name: name.dig("family"),
        date_of_birth: fhir["birthDate"],
        gender: fhir["gender"],
        address_line_1: address.dig("line")&.first,
        address_line_2: address.dig("line")&.at(1),
        city: address["city"],
        postcode: address["postalCode"],
        phone: phone&.dig("value"),
        gp_ods_code: gp_ods,
        gp_name: gp_name,
        nominated_pharmacy_ods: pharmacy_ods
      }
    end
  end
end
