FactoryBot.define do
  factory :schedule do
    association :medication
    time_of_day { "08:00" }
    days_of_week { "daily" }
    instructions { "With food" }
  end
end