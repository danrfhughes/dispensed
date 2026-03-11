require 'rails_helper'

RSpec.describe GenerateDailyDosesJob, type: :job do
  let(:user) { create(:user) }
  let(:medication) { create(:medication, patient_profile: user.patient_profile, active: true) }
  let!(:schedule) { create(:schedule, medication: medication, time_of_day: "08:00", days_of_week: "daily") }

  describe '#perform' do
    it 'creates a dose for each active schedule' do
      Dose.destroy_all
      expect {
        GenerateDailyDosesJob.new.perform(Date.current)
      }.to change(Dose, :count).by(1)
    end

    it 'is idempotent — does not create duplicate doses' do
      GenerateDailyDosesJob.new.perform(Date.current)
      expect {
        GenerateDailyDosesJob.new.perform(Date.current)
      }.not_to change(Dose, :count)
    end

    it 'does not create doses for archived medications' do
      medication.archive!
      expect {
        GenerateDailyDosesJob.new.perform(Date.current)
      }.not_to change(Dose, :count)
    end

    it 'does not create doses when schedule is not active on that day' do
      schedule.update!(days_of_week: "monday")
      tuesday = Date.parse("2026-03-10") # a Tuesday
      expect {
        GenerateDailyDosesJob.new.perform(tuesday)
      }.not_to change(Dose, :count)
    end

    it 'sets scheduled_for to the correct datetime' do
      GenerateDailyDosesJob.new.perform(Date.current)
      dose = Dose.last
      expect(dose.scheduled_for.hour).to eq(8)
      expect(dose.scheduled_for.min).to eq(0)
    end
  end
end