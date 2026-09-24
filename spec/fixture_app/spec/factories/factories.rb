FactoryBot.define do
  sequence(:email) { |n| "person#{n}@studiz.example" }

  factory :user do
    email
    password { "hemmeligt123" }

    trait :onboarded do
      onboarded { true }
    end
  end

  factory :student do
    first_name { "Mette" }
    last_name { "Frederiksen" }
    automatic_verified { false }

    after(:create) do |student|
      create(:user, role: student) unless student.user
    end

    trait :with_user do
      after(:create) { |student| student.user || create(:user, role: student) }
    end
  end

  factory :provider do
    sequence(:name) { |n| "Café Vivaldi #{n}" }
    registration_number { "12345678" }

    after(:create) do |provider|
      create(:user, role: provider) unless provider.user
    end
  end

  factory :institution do
    sequence(:name) { |n| "Københavns Universitet #{n}" }
    sequence(:slug) { |n| "ku#{n}" }
    allow_events { false }

    trait :with_user do
      after(:create) do |institution|
        employee = create(:employee, institution: institution, leader: true)
        create(:user, role: employee)
      end
    end

    trait :with_specialities do
      after(:create) do |institution|
        create(:speciality, institution: institution, name: "Jura")
        create(:speciality, institution: institution, name: "Medicin")
      end
    end
  end

  factory :employee, class: "Institutions::Employee" do
    institution
    name { "Leder Ledersen" }
    leader { false }
  end

  factory :speciality do
    institution
    name { "Jura" }
  end

  factory :student_organisation, class: "Institutions::StudentOrganisation" do
    sequence(:name) { |n| "Studenterrådet #{n}" }

    after(:create) do |org|
      create(:user, role: org) unless org.user
    end
  end

  factory :student_organisation_membership do
    student_organisation
    sequence(:name) { |n| "Medlem #{n}" }
    email
    membership_type { "member" }
  end

  factory :category do
    sequence(:name) { |n| "Kategori #{n}" }
  end

  factory :event, class: "Events::Event" do
    institution
    sequence(:name) { |n| "Fredagsbar #{n}" }
    description { "<div>Kom til fredagsbar</div>" }
    starts_at { Time.zone.parse("2026-10-01 14:00") }
  end

  factory :ticket_type, class: "Events::TicketType" do
    event
    name { "Standard" }
    price { 50 }
  end

  factory :discount do
    provider
    sequence(:name_da) { |n| "Kaffe #{n * 10}%" }
    status { "active" }
  end

  factory :invoice do
    provider
    sequence(:number) { |n| "F-2026-#{n}" }
    amount_cents { 12_500 }
  end

  factory :lead do
    sequence(:name) { |n| "Lead #{n}" }
    email
    status { "new" }
  end

  factory :user_message do
    user
    body { "Hej" }
  end
end
