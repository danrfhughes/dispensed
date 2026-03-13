FactoryBot.define do
  factory :schedule do
    association :medication
    time_of_day { "08:00" }
    days_of_week { "daily" }
    instructions { "With food" }

    trait :routine do
      routine_anchor { "breakfast" }
      food_relation { "with_food" }
      time_of_day { nil }
    end
  end
end