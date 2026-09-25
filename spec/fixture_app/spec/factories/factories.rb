# Factories and traits modelled on the ones Studiz specs use (Appendix A of the
# 1.1 brief): role factories create their user in `after(:create)` or through a
# `:with_user` trait, namespaced models use underscored factory names.
FactoryBot.define do
  sequence(:email) { |n| "person#{n}@studiz.example" }

  factory :user do
    email
    password { "hemmeligt123" }

    trait :onboarded do
      onboarded { true }
    end
  end

  # ---- roles ----------------------------------------------------------------

  factory :student do
    first_name { "Mette" }
    last_name { "Frederiksen" }
    automatic_verified { false }

    after(:create) do |student|
      create(:user, role: student) && student.reload unless student.user
    end

    trait :with_user do
      after(:create) { |student| student.user || (create(:user, role: student) && student.reload) }
    end

    trait :verified do
      automatic_verified { true }
    end

    trait :onboarded do
      after(:create) { |student| student.user.update!(onboarded: true) }
    end
  end

  factory :provider do
    sequence(:name) { |n| "Café Vivaldi #{n}" }
    registration_number { nil }

    after(:create) do |provider|
      create(:user, role: provider) && provider.reload unless provider.user
    end

    trait :with_user do
      after(:create) { |provider| provider.user || (create(:user, role: provider) && provider.reload) }
    end

    trait :with_cvr do
      registration_number { "12345678" }
    end
  end

  factory :institution do
    sequence(:name) { |n| "Københavns Universitet #{n}" }
    sequence(:slug) { |n| "ku#{n}" }
    allow_events { false }

    # Studiz: the institution signs in through its leader employee's user.
    trait :with_user do
      after(:create) do |institution|
        employee = create(:employee, :leader, institution: institution)
        create(:user, role: employee)
      end
    end

    trait :with_specialities do
      after(:create) do |institution|
        create(:speciality, institution: institution, name: "Jura")
        create(:speciality, institution: institution, name: "Medicin")
      end
    end

    trait :allow_events do
      allow_events { true }
    end
  end

  factory :employee, class: "Institutions::Employee" do
    institution
    name { "Leder Ledersen" }
    employee_type { "employee" }

    trait :leader do
      employee_type { "leader" }
    end

    trait :with_user do
      after(:create) { |employee| employee.user || create(:user, role: employee) }
    end
  end

  factory :institutions_student_organisation, class: "Institutions::StudentOrganisation", aliases: [:student_organisation] do
    sequence(:name) { |n| "Studenterrådet #{n}" }

    after(:create) do |org|
      create(:user, role: org) && org.reload unless org.user
    end

    trait :with_user do
      after(:create) { |org| org.user || (create(:user, role: org) && org.reload) }
    end
  end

  factory :admin do
    name { "Anna Admin" }

    after(:create) do |admin|
      create(:user, role: admin) && admin.reload unless admin.user
    end

    trait :with_user do
      after(:create) { |admin| admin.user || (create(:user, role: admin) && admin.reload) }
    end
  end

  factory :company do
    sequence(:name) { |n| "Firma #{n} ApS" }
    cvr { "87654321" }

    after(:create) do |company|
      create(:user, role: company) && company.reload unless company.user
    end

    trait :with_user do
      after(:create) { |company| company.user || (create(:user, role: company) && company.reload) }
    end
  end

  factory :team_member do
    name { "Tom Teammedlem" }
    department { "Support" }

    after(:create) do |member|
      create(:user, role: member) && member.reload unless member.user
    end

    trait :with_user do
      after(:create) { |member| member.user || (create(:user, role: member) && member.reload) }
    end
  end

  # ---- content --------------------------------------------------------------

  factory :speciality do
    institution
    name { "Jura" }
  end

  factory :student_organisation_membership do
    student_organisation
    sequence(:name) { |n| "Medlem #{n}" }
    email
    membership_type { "member" }

    trait :board do
      membership_type { "board" }
    end
  end

  factory :category do
    sequence(:name) { |n| "Kategori #{n}" }
  end

  factory :event, class: "Events::Event" do
    institution
    sequence(:name) { |n| "Fredagsbar #{n}" }
    description { "<div>Kom til fredagsbar</div>" }
    starts_at { Time.zone.parse("2026-10-01 14:00") }

    trait :published do
      published { true }
    end

    trait :upcoming do
      starts_at { 3.days.from_now.change(hour: 14) }
    end

    trait :past do
      starts_at { 30.days.ago.change(hour: 14) }
    end

    trait :with_tickets do
      after(:create) do |event|
        create(:ticket_type, event: event, name: "Standard", price: 50)
        create(:ticket_type, event: event, name: "VIP", price: 150)
      end
    end
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

    trait :active do
      status { "active" }
    end

    trait :draft do
      status { "draft" }
    end

    trait :inactive do
      status { "inactive" }
    end

    trait :archived do
      archived { true }
    end

    trait :with_image do
      cover_image { "cover.png" }
    end

    trait :with_categories do
      after(:create) { |discount| discount.categories << create(:category, name: "Fest") }
    end
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

    trait :contacted do
      status { "contacted" }
    end

    trait :high_priority do
      priority { :high }
    end
  end

  factory :user_message do
    user
    body { "Hej" }
  end

  factory :note do
    association :notable, factory: :discount
    body { "En note" }

    trait :with_author do
      author { create(:user) }
    end
  end
end
