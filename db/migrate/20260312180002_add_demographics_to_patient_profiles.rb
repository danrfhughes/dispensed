class AddDemographicsToPatientProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :patient_profiles, :first_name, :string
    add_column :patient_profiles, :last_name, :string
    add_column :patient_profiles, :gender, :string
    add_column :patient_profiles, :address_line_1, :string
    add_column :patient_profiles, :address_line_2, :string
    add_column :patient_profiles, :city, :string
    add_column :patient_profiles, :postcode, :string
    add_column :patient_profiles, :phone, :string
    add_reference :patient_profiles, :gp_organisation, foreign_key: { to_table: :organisations }, null: true
    add_reference :patient_profiles, :nominated_pharmacy, foreign_key: { to_table: :organisations }, null: true
    add_column :patient_profiles, :demographics_fetched_at, :datetime
  end
end
