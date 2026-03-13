# frozen_string_literal: true

module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    # POST /users/auth/nhslogin/callback
    def nhslogin
      auth = request.env["omniauth.auth"]
      @user = User.from_omniauth(auth)

      if @user.persisted?
        update_patient_profile!(auth)
        sync_demographics!(auth)
        sign_in_and_redirect @user, event: :authentication
        set_flash_message(:notice, :success, kind: "NHS Login") if is_navigational_format?
      else
        session["devise.nhslogin_data"] = auth.except(:extra)
        redirect_to new_user_registration_url, alert: "Could not sign in with NHS Login."
      end
    end

    def failure
      redirect_to root_path, alert: "NHS Login authentication failed: #{failure_message}"
    end

    private

    # Map NHS Login identity claims to PatientProfile
    def update_patient_profile!(auth)
      profile = @user.patient_profile
      return unless profile

      extra = auth.dig(:extra) || {}
      vot = extra[:vot] || identity_level_from_vot(auth)

      profile.update(
        nhs_login_identity_level: vot,
        nhs_number: extra[:nhs_number] || profile.nhs_number,
        date_of_birth: auth.dig(:info, :birthdate) || profile.date_of_birth
      )
    end

    # Fetch demographics from PDS for P5+ users (skips if recently fetched)
    def sync_demographics!(auth)
      profile = @user.patient_profile
      return unless profile

      access_token = auth.dig(:credentials, :token)
      NhsApi::DemographicsSync.call(profile, access_token: access_token)
    rescue => e
      Rails.logger.error("Demographics sync failed: #{e.message}")
      # Don't block login if demographics sync fails
    end

    # Parse Vector of Trust claim to identity level (P0, P5, P9)
    def identity_level_from_vot(auth)
      vot_raw = auth.dig(:extra, :raw_info, :vot)
      return nil unless vot_raw

      case vot_raw
      when /P9/ then "P9"
      when /P5/ then "P5"
      when /P0/ then "P0"
      else vot_raw
      end
    end
  end
end
