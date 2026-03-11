class CreateDoses < ActiveRecord::Migration[8.1]
  def change
    create_table :doses do |t|
      t.references :medication, null: false, foreign_key: true
      t.references :schedule, null: false, foreign_key: true
      t.datetime :scheduled_for, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :taken_at
      t.string :notes

      t.timestamps
    end

    add_index :doses, [:medication_id, :scheduled_for]
  end
end