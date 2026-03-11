class CreatePatientProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :patient_profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :nhs_number
      t.string :fhir_id
      t.date :date_of_birth

      t.timestamps
    end

    add_index :patient_profiles, :nhs_number, unique: true, where: "nhs_number IS NOT NULL"
  end
end