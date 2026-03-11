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

    context "when a conflicting daily schedule already exists" do
      before { create(:schedule, medication: medication, days_of_week: "daily") }

      it "re-renders the form with a conflict error" do
        post medication_schedules_path(medication), params: {
          schedule: { time_of_day: "18:00", days_of_week: "monday", instructions: "" }
        }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("conflicts")
      end
    end

    context "with missing time" do
      it "re-renders the form with a validation error" do
        post medication_schedules_path(medication), params: {
          schedule: { time_of_day: "", days_of_week: "daily", instructions: "" }
        }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Time of day")
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
