# frozen_string_literal: true

module NhsApi
  # Syncs patient demographics from PDS FHIR to a PatientProfile.
  # Called after NHS Login for P5+ users.
  #
  # Usage:
  #   NhsApi::DemographicsSync.call(patient_profile)
  class DemographicsSync
    MINIMUM_IDENTITY_LEVEL = "P5"
    IDENTITY_LEVELS = %w[P0 P5 P9].freeze

    def self.call(patient_profile, access_token: nil)
      new(patient_profile, access_token: access_token).call
    end

    def initialize(patient_profile, access_token: nil)
      @profile = patient_profile
      @access_token = access_token
    end

    def call
      return unless should_sync?

      data = pds_client.fetch_patient(@profile.nhs_number, access_token: @access_token)

      update_demographics(data)
      link_gp_practice(data[:gp_ods_code], data[:gp_name])
      link_nominated_pharmacy(data[:nominated_pharmacy_ods])

      @profile.update!(demographics_fetched_at: Time.current)
      @profile
    rescue NhsApi::PdsClient::NotFound => e
      Rails.logger.warn("DemographicsSync: #{e.message}")
      nil
    rescue NhsApi::PdsClient::Error => e
      Rails.logger.error("DemographicsSync: #{e.message}")
      nil
    end

    private

    def should_sync?
      return false if @profile.nhs_number.blank?
      return false unless sufficient_identity_level?
      return false unless @profile.demographics_stale?

      true
    end

    def sufficient_identity_level?
      level = @profile.nhs_login_identity_level
      return false if level.blank?

      level_index = IDENTITY_LEVELS.index(level)
      min_index = IDENTITY_LEVELS.index(MINIMUM_IDENTITY_LEVEL)
      return false unless level_index && min_index

      level_index >= min_index
    end

    def update_demographics(data)
      @profile.assign_attributes(
        first_name: data[:first_name],
        last_name: data[:last_name],
        date_of_birth: data[:date_of_birth] || @profile.date_of_birth,
        gender: data[:gender],
        address_line_1: data[:address_line_1],
        address_line_2: data[:address_line_2],
        city: data[:city],
        postcode: data[:postcode],
        phone: data[:phone]
      )
      @profile.save!
    end

    def link_gp_practice(ods_code, name)
      return if ods_code.blank?

      org = Organisation.find_or_create_by!(ods_code: ods_code) do |o|
        o.name = name || "GP Practice #{ods_code}"
        o.organisation_type = "gp_practice"
      end
      @profile.update!(gp_organisation_id: org.id)
    end

    def link_nominated_pharmacy(ods_code)
      return if ods_code.blank?

      org = Organisation.find_or_create_by!(ods_code: ods_code) do |o|
        o.name = "Pharmacy #{ods_code}"
        o.organisation_type = "pharmacy"
      end
      @profile.update!(nominated_pharmacy_id: org.id)
    end

    def pds_client
      NhsApi::PdsClient.for_environment
    end
  end
end
