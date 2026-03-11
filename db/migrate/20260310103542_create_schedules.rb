class CreateSchedules < ActiveRecord::Migration[8.1]
  def change
    create_table :schedules do |t|
      t.references :medication, null: false, foreign_key: true
      t.time :time_of_day, null: false
      t.string :days_of_week, default: "daily", null: false
      t.string :instructions

      t.timestamps
    end
  end
end