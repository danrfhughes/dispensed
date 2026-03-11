FactoryBot.define do
  factory :medication do
    transient { user { create(:user) } }
    patient_profile { user.patient_profile }
    name { "Metformin" }
    dose { "500mg" }
    form { "tablet" }
    days_supply { 28 }
    active { true }
    last_dispensed_on { Date.today }
  end
end
