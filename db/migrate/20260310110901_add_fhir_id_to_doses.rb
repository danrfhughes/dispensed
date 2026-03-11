class AddFhirIdToDoses < ActiveRecord::Migration[8.1]
  def change
    add_column :doses, :fhir_id, :string
  end
end
