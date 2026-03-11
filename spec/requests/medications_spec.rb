require 'rails_helper'

RSpec.describe "Medications", type: :request do
  let(:user) { create(:user) }
  let!(:medication) { create(:medication, patient_profile: user.patient_profile) }

  before { sign_in user }

  describe "GET /medications" do
    it "lists the user's active medications" do
      get medications_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(medication.name)
    end

    it "does not show another user's medications" do
      create(:medication, patient_profile: create(:user).patient_profile, name: "OtherDrug")
      get medications_path
      expect(response.body).not_to include("OtherDrug")
    end
  end

  describe "GET /medications/:id" do
    it "shows the medication and its schedules section" do
      get medication_path(medication)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(medication.name)
      expect(response.body).to include("Schedules")
    end

    it "returns 404 for another user's medication" do
      other_med = create(:medication, patient_profile: create(:user).patient_profile)
      get medication_path(other_med)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /medications/new" do
    it "renders the new medication form" do
      get new_medication_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /medications" do
    context "with valid params" do
      it "creates the medication and redirects to the list" do
        expect {
          post medications_path, params: { medication: { name: "Lisinopril", dose: "10mg", form: "tablet", days_supply: 28 } }
        }.to change(Medication, :count).by(1)
        expect(response).to redirect_to(medications_path)
      end
    end

    context "with invalid params" do
      it "re-renders the form with errors" do
        post medications_path, params: { medication: { name: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "PATCH /medications/:id" do
    context "with valid params" do
      it "updates the medication and redirects" do
        patch medication_path(medication), params: { medication: { name: "Updated Name" } }
        expect(response).to redirect_to(medications_path)
        expect(medication.reload.name).to eq("Updated Name")
      end
    end

    context "with invalid params" do
      it "re-renders the form with errors" do
        patch medication_path(medication), params: { medication: { name: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /medications/:id" do
    it "archives the medication and redirects" do
      delete medication_path(medication)
      expect(response).to redirect_to(medications_path)
      expect(medication.reload.active).to be false
    end
  end

  describe "unauthenticated access" do
    before { sign_out user }

    it "redirects to sign in" do
      get medications_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
