class CreatePharmacies < ActiveRecord::Migration[8.1]
  def change
    create_table :pharmacies do |t|
      t.string :name
      t.text :address
      t.string :phone
      t.string :email
      t.references :patient_profile, null: false, foreign_key: true

      t.timestamps
    end
  end
end
