FactoryBot.define do
  factory :dose do
    association :medication
    association :schedule
    scheduled_for { Time.current }
    status { "pending" }
  end
end