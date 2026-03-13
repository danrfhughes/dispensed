class CreateOrganisations < ActiveRecord::Migration[8.1]
  def change
    create_table :organisations do |t|
      t.string :ods_code, null: false
      t.string :name, null: false
      t.string :organisation_type
      t.text :address
      t.string :phone
      t.string :email
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :organisations, :ods_code, unique: true
    add_index :organisations, :organisation_type
  end
end
