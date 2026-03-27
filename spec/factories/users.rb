FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }

    trait :with_2fa do
      otp_secret { User.generate_otp_secret }
      consumed_timestep { 1 }
    end

    trait :exempt_from_2fa do
      otp_required_for_login { false }
    end
  end
end
