class AddRoutineColumnsToSchedules < ActiveRecord::Migration[8.1]
  def change
    add_column :schedules, :routine_anchor, :string
    add_column :schedules, :food_relation, :string
    change_column_null :schedules, :time_of_day, true
  end
end
