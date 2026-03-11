class AddActiveToSchedules < ActiveRecord::Migration[8.1]
  def change
    add_column :schedules, :active, :boolean, null: false, default: true
  end
end
