class MigrateMedicationOwnershipToPatientProfile < ActiveRecord::Migration[8.1]
  def up
    add_reference :medications, :patient_profile, null: true, foreign_key: true

    execute <<~SQL
      UPDATE medications
      SET patient_profile_id = (
        SELECT patient_profiles.id
        FROM patient_profiles
        WHERE patient_profiles.user_id = medications.user_id
      )
    SQL

    change_column_null :medications, :patient_profile_id, false
    remove_reference :medications, :user, foreign_key: true
  end

  def down
    add_reference :medications, :user, null: true, foreign_key: true

    execute <<~SQL
      UPDATE medications
      SET user_id = (
        SELECT patient_profiles.user_id
        FROM patient_profiles
        WHERE patient_profiles.id = medications.patient_profile_id
      )
    SQL

    change_column_null :medications, :user_id, false
    remove_reference :medications, :patient_profile, foreign_key: true
  end
end
