require "rails_helper"

RSpec.describe "Schedules", type: :system do
  let(:user) { create(:user) }
  let!(:medication) { create(:medication, user: user, name: "Metformin", dose: "500mg") }

  before { sign_in user }

  describe "create with specific time" do
    it "adds a schedule and generates a dose" do
      visit new_medication_schedule_path(medication)

      within("#single-schedule-section") do
        choose "At a specific time"
        fill_in "schedule_time_of_day", with: "09:00"
      end
      click_button "Create Schedule"

      expect(page).to have_content("Schedule added")
      expect(medication.schedules.active.count).to eq(1)
    end
  end

  describe "create with routine anchor" do
    it "adds a breakfast routine schedule" do
      visit new_medication_schedule_path(medication)

      within("#single-schedule-section") do
        choose "With breakfast"
      end
      click_button "Create Schedule"

      expect(page).to have_content("Schedule added")
      schedule = medication.schedules.last
      expect(schedule.routine_anchor).to eq("breakfast")
    end
  end

  describe "create with food relation" do
    it "saves food relation when set" do
      visit new_medication_schedule_path(medication)

      within("#single-schedule-section") do
        choose "With breakfast"
      end
      choose "Before food (empty stomach)"
      click_button "Create Schedule"

      expect(page).to have_content("Schedule added")
      schedule = medication.schedules.last
      expect(schedule.food_relation).to eq("before_food")
    end
  end

  describe "validation errors" do
    it "shows error when no time and no anchor selected" do
      visit new_medication_schedule_path(medication)

      within("#single-schedule-section") do
        choose "At a specific time"
      end
      click_button "Create Schedule"

      expect(page).to have_css(".bg-red-100")
    end
  end

  describe "overlap conflict" do
    it "shows error when creating schedule at same time slot" do
      create(:schedule, medication: medication, time_of_day: "08:00", days_of_week: "daily")

      visit new_medication_schedule_path(medication)

      choose "Once a day"
      within("#single-schedule-section") do
        choose "At a specific time"
        fill_in "schedule_time_of_day", with: "08:00"
      end
      click_button "Create Schedule"

      expect(page).to have_content("conflicts")
    end

    it "allows creating a second schedule at a different time" do
      create(:schedule, medication: medication, time_of_day: "08:00", days_of_week: "daily")

      visit new_medication_schedule_path(medication)

      choose "Once a day"
      within("#single-schedule-section") do
        choose "At a specific time"
        fill_in "schedule_time_of_day", with: "22:00"
      end
      click_button "Create Schedule"

      expect(page).to have_content("Schedule added")
      expect(medication.schedules.active.count).to eq(2)
    end
  end

  describe "edit" do
    let!(:schedule) do
      create(:schedule, medication: medication, time_of_day: "08:00", days_of_week: "daily")
    end

    it "updates schedule time" do
      visit edit_medication_schedule_path(medication, schedule)

      fill_in "schedule_time_of_day", with: "09:30"
      click_button "Update Schedule"

      expect(page).to have_content("Schedule updated")
    end
  end

  describe "archive" do
    let!(:schedule) do
      create(:schedule, medication: medication, time_of_day: "08:00", days_of_week: "daily")
    end

    it "removes a schedule" do
      visit medication_path(medication)

      click_button "Remove"

      expect(page).to have_content("Schedule removed")
    end
  end

  describe "specific days" do
    it "creates a schedule for specific days" do
      visit new_medication_schedule_path(medication)

      within("#single-schedule-section") do
        choose "At a specific time"
        fill_in "schedule_time_of_day", with: "08:00"
      end
      choose "Specific days"
      check "Monday"
      check "Wednesday"
      check "Friday"
      click_button "Create Schedule"

      expect(page).to have_content("Schedule added")
      schedule = medication.schedules.last
      expect(schedule.days_of_week).to include("monday")
      expect(schedule.days_of_week).to include("wednesday")
      expect(schedule.days_of_week).to include("friday")
    end
  end
end
