class AddFhirFieldsToMedications < ActiveRecord::Migration[8.1]
  def change
    add_column :medications, :dmd_code, :string
    add_column :medications, :fhir_id, :string
  end
end
