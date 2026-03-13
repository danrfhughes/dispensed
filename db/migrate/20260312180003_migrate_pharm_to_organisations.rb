class MigratePharmToOrganisations < ActiveRecord::Migration[8.1]
  def up
    # Copy existing pharmacy records to organisations
    execute <<~SQL
      INSERT INTO organisations (ods_code, name, organisation_type, address, phone, email, active, created_at, updated_at)
      SELECT
        'LEGACY-' || id,
        name,
        'pharmacy',
        address,
        phone,
        email,
        true,
        created_at,
        updated_at
      FROM pharmacies
    SQL

    # Link patient_profiles to their migrated pharmacy organisations
    execute <<~SQL
      UPDATE patient_profiles
      SET nominated_pharmacy_id = o.id
      FROM pharmacies p
      JOIN organisations o ON o.ods_code = 'LEGACY-' || p.id
      WHERE p.patient_profile_id = patient_profiles.id
    SQL

    drop_table :pharmacies
  end

  def down
    create_table :pharmacies do |t|
      t.text :address
      t.string :email
      t.string :name
      t.bigint :patient_profile_id, null: false
      t.string :phone
      t.timestamps
    end
    add_index :pharmacies, :patient_profile_id
    add_foreign_key :pharmacies, :patient_profiles
  end
end
