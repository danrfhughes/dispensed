class CreateMedications < ActiveRecord::Migration[8.1]
  def change
    create_table :medications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :dose
      t.string :form
      t.text :notes
      t.date :start_date
      t.date :end_date
      t.integer :days_supply, default: 28, null: false
      t.date :last_dispensed_on
      t.boolean :active, default: true, null: false
      t.timestamps
    end
  end
end