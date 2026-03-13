require 'rails_helper'

RSpec.describe "Schedules", type: :request do
  let(:user) { create(:user) }
  let(:medication) { create(:medication, patient_profile: user.patient_profile) }

  before do
    sign_in user
    allow_any_instance_of(GenerateDailyDosesJob).to receive(:perform)
  end

  describe "GET /medications/:medication_id/schedules/new" do
    it "renders the new schedule form" do
      get new_medication_schedule_path(medication)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Add schedule")
    end
  end

  describe "POST /medications/:medication_id/schedules" do
    context "with a daily schedule" do
      it "creates the schedule and redirects to the medication" do
        expect {
          post medication_schedules_path(medication), params: {
            schedule: { time_of_day: "08:00", days_of_week: "daily", instructions: "" }
          }
        }.to change(Schedule, :count).by(1)
        expect(response).to redirect_to(medication_path(medication))
      end
    end

    context "with specific days" do
      it "creates the schedule with the correct days" do
        post medication_schedules_path(medication), params: {
          schedule: { time_of_day: "09:00", days_of_week: "specific", instructions: "" },
          "schedule" => { "days_of_week" => "specific", "days_of_week_multi" => ["monday", "wednesday"], "time_of_day" => "09:00" }
        }
        expect(response).to redirect_to(medication_path(medication))
        expect(Schedule.last.days_of_week).to eq("monday,wednesday")
      end
    end

    context "when a conflicting schedule already exists at the same time" do
      before { create(:schedule, medication: medication, days_of_week: "daily", time_of_day: "08:00") }

      it "re-renders the form with a conflict error" do
        post medication_schedules_path(medication), params: {
          schedule: { time_of_day: "08:00", days_of_week: "daily", instructions: "" }
        }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("conflicts")
      end

      it "allows a schedule at a different time" do
        expect {
          post medication_schedules_path(medication), params: {
            schedule: { time_of_day: "22:00", days_of_week: "daily", instructions: "" }
          }
        }.to change(Schedule, :count).by(1)
        expect(response).to redirect_to(medication_path(medication))
      end
    end

    context "with a routine anchor and no explicit time" do
      it "creates the schedule with the anchor default time" do
        expect {
          post medication_schedules_path(medication), params: {
            schedule: { routine_anchor: "breakfast", days_of_week: "daily", time_of_day: "", instructions: "" }
          }
        }.to change(Schedule, :count).by(1)
        expect(response).to redirect_to(medication_path(medication))
        expect(Schedule.last.routine_anchor).to eq("breakfast")
        expect(Schedule.last.time_of_day.strftime("%H:%M")).to eq("08:00")
      end
    end

    context "with a routine anchor and explicit time" do
      it "keeps the explicit time" do
        post medication_schedules_path(medication), params: {
          schedule: { routine_anchor: "breakfast", time_of_day: "09:30", days_of_week: "daily", instructions: "" }
        }
        expect(Schedule.last.time_of_day.strftime("%H:%M")).to eq("09:30")
      end
    end

    context "with a routine anchor and food relation" do
      it "saves both fields" do
        post medication_schedules_path(medication), params: {
          schedule: { routine_anchor: "breakfast", food_relation: "with_food", days_of_week: "daily", time_of_day: "", instructions: "" }
        }
        expect(Schedule.last.routine_anchor).to eq("breakfast")
        expect(Schedule.last.food_relation).to eq("with_food")
      end
    end

    context "with missing time and no routine anchor" do
      it "re-renders the form with a validation error" do
        post medication_schedules_path(medication), params: {
          schedule: { time_of_day: "", days_of_week: "daily", instructions: "" }
        }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Time of day")
      end
    end

    context "with frequency_type=twice_daily (SCHED-3)" do
      it "creates two schedules with different anchors" do
        expect {
          post medication_schedules_path(medication), params: {
            schedule: {
              frequency_type: "twice_daily",
              morning_anchor: "breakfast",
              morning_food_relation: "with_food",
              morning_time_of_day: "",
              evening_anchor: "bedtime",
              evening_food_relation: "",
              evening_time_of_day: "",
              days_of_week: "daily",
              instructions: "Take with water"
            }
          }
        }.to change(Schedule, :count).by(2)
        expect(response).to redirect_to(medication_path(medication))

        schedules = medication.schedules.active.order(:time_of_day)
        expect(schedules.first.routine_anchor).to eq("breakfast")
        expect(schedules.first.food_relation).to eq("with_food")
        expect(schedules.last.routine_anchor).to eq("bedtime")
      end

      it "creates two schedules with clock times" do
        expect {
          post medication_schedules_path(medication), params: {
            schedule: {
              frequency_type: "twice_daily",
              morning_anchor: "",
              morning_food_relation: "",
              morning_time_of_day: "08:00",
              evening_anchor: "",
              evening_food_relation: "",
              evening_time_of_day: "20:00",
              days_of_week: "daily",
              instructions: ""
            }
          }
        }.to change(Schedule, :count).by(2)

        times = medication.schedules.active.order(:time_of_day).map { |s| s.time_of_day.strftime("%H:%M") }
        expect(times).to eq(["08:00", "20:00"])
      end

      it "rolls back both if one is invalid (missing time and no anchor)" do
        expect {
          post medication_schedules_path(medication), params: {
            schedule: {
              frequency_type: "twice_daily",
              morning_anchor: "breakfast",
              morning_food_relation: "",
              morning_time_of_day: "",
              evening_anchor: "",
              evening_food_relation: "",
              evening_time_of_day: "",
              days_of_week: "daily",
              instructions: ""
            }
          }
        }.not_to change(Schedule, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "shares days_of_week and instructions across both schedules" do
        post medication_schedules_path(medication), params: {
          schedule: {
            frequency_type: "twice_daily",
            morning_anchor: "breakfast",
            morning_food_relation: "",
            morning_time_of_day: "",
            evening_anchor: "bedtime",
            evening_food_relation: "",
            evening_time_of_day: "",
            days_of_week: "daily",
            instructions: "Swallow whole"
          }
        }
        schedules = medication.schedules.active
        expect(schedules.pluck(:days_of_week).uniq).to eq(["daily"])
        expect(schedules.pluck(:instructions).uniq).to eq(["Swallow whole"])
      end
    end

    context "for another user's medication" do
      let(:other_medication) { create(:medication, patient_profile: create(:user).patient_profile) }

      it "returns 404" do
        post medication_schedules_path(other_medication), params: {
          schedule: { time_of_day: "08:00", days_of_week: "daily" }
        }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /medications/:medication_id/schedules/:id/edit" do
    let(:schedule) { create(:schedule, medication: medication) }

    it "renders the edit form" do
      get edit_medication_schedule_path(medication, schedule)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit schedule")
    end
  end

  describe "PATCH /medications/:medication_id/schedules/:id" do
    let(:schedule) { create(:schedule, medication: medication, days_of_week: "daily") }

    context "with valid params" do
      it "updates the schedule and redirects" do
        patch medication_schedule_path(medication, schedule), params: {
          schedule: { time_of_day: "20:00", days_of_week: "daily" }
        }
        expect(response).to redirect_to(medication_path(medication))
        expect(schedule.reload.time_of_day.strftime("%H:%M")).to eq("20:00")
      end
    end

    context "with invalid params" do
      it "re-renders the form with errors" do
        patch medication_schedule_path(medication, schedule), params: {
          schedule: { time_of_day: "", days_of_week: "daily" }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /medications/:medication_id/schedules/:id" do
    let!(:schedule) { create(:schedule, medication: medication) }

    it "archives the schedule (soft delete) and redirects" do
      delete medication_schedule_path(medication, schedule)
      expect(response).to redirect_to(medication_path(medication))
      expect(schedule.reload.active).to be false
    end

    it "preserves the schedule record in the database" do
      expect {
        delete medication_schedule_path(medication, schedule)
      }.not_to change(Schedule, :count)
    end
  end

  describe "unauthenticated access" do
    before { sign_out user }

    it "redirects to sign in" do
      get new_medication_schedule_path(medication)
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
