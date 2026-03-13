class AddNhsLoginIdentityLevelToPatientProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :patient_profiles, :nhs_login_identity_level, :string
  end
end
