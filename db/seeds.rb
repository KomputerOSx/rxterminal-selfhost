# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Role/Permission/RolePermission baseline records normally get synced at boot time by
# config/initializers/rbac_registry.rb, so every process (web, jobs, console) picks up
# config/rbac.yml regardless of the deploy tool. Called again here explicitly, not just
# trusted to have already run: on a brand-new database, db:prepare's schema:load and
# db:seed happen in the same process as an after_initialize that already fired (and
# skipped, since the tables didn't exist yet) before schema:load created them - without
# this call, the lookups below would raise on a database's very first deploy.
RbacRegistry.sync!

system_admin = Role.find_by!(scope: :system, name: Role::SYSTEM_ADMIN)

if Rails.env.local? && ENV["SYSTEM_ADMIN_EMAIL"].present?
  if (user = User.find_by(email: ENV["SYSTEM_ADMIN_EMAIL"]))
    user.grant_role!(system_admin)
  end
end

if Rails.env.development?
  require "faker"

  # Solo dev account: admin@mail.com / SuperKey99!, owner of "The Admin Clinic",
  # and also a system admin so both the org app and the /admin namespace are
  # reachable from a single login. Created on first run so a fresh database
  # doesn't need a manual sign-up before seeding.
  dev_owner_email = "admin@mail.com"

  owner = User.find_by(email: dev_owner_email)

  if owner.nil?
    owner = User.create!(
      email: dev_owner_email,
      password: "SuperKey99!",
      first_name: "Admin",
      last_name: "User",
      confirmed_at: Time.current
    )
    Organization.create_for!(owner, name: "The Admin Clinic", slug_base: "the-admin-clinic")
  end

  owner.grant_role!(system_admin)

  org = owner.memberships.joins(membership_roles: :role)
             .where(roles: { name: Role::APP_OWNER, scope: :app })
             .first&.organization

  if org
    org.update!(name: "The Admin Clinic") unless org.name == "The Admin Clinic"
    org.update!(time_zone: "London") unless org.time_zone == "London"

    # Demo address for the org.
    if org.address_line1.blank?
      org.update!(
        address_line1: "1 London Bridge Street",
        address_city: "London",
        address_postal_code: "SE1 9GF",
        address_country: "GB"
      )
    end

    # Solo org - strip any other members so admin@mail.com is the sole user.
    stray_members = org.memberships.where.not(user: owner)
    stray_user_ids = stray_members.pluck(:user_id)
    stray_members.destroy_all
    User.where(id: stray_user_ids).where.missing(:memberships).destroy_all

    puts "'#{org.name}' is a solo org (#{dev_owner_email}), also granted system admin"

    # Business plan via the no-card trial mechanism (not a real Stripe subscription) so this
    # works in dev regardless of Stripe credentials being configured.
    unless org.subscribed?
      org.update!(trial_plan_key: Billing::Plans::BUSINESS.key, trial_ends_at: OrganizationTrial::TRIAL_DAYS.days.from_now)
    end

    puts "'#{org.name}' is on the #{org.current_plan&.name || "no"} plan"

    default_calendar = org.calendars.find_by(is_default: true) || org.calendars.first!

    seed_services = [
      { internal_name: "flu-jab", display_name: "Flu Jab", estimated_duration: 15, requires_appointment: true, allows_immediate: false, icon: "vaccines", featured: true },
      { internal_name: "blood-pressure", display_name: "Blood pressure check", estimated_duration: 10, requires_appointment: true, allows_immediate: true, icon: "monitor_heart" },
      { internal_name: "prescription", display_name: "Prescription collection", estimated_duration: 5, requires_appointment: false, allows_immediate: true, icon: "medication" }
    ]

    services = org.services.visible.to_a
    seed_services.each_with_index do |attrs, index|
      next if services.any? { |service| service.internal_name == attrs[:internal_name] }

      services << org.services.create!(
        attrs.merge(
          calendar: default_calendar,
          active: true,
          allows_private_consultation: false,
          display_order: index
        )
      )
    end

    puts "Ensured #{services.size} services in org '#{org.name}'"

    # This is dev-only demo data - reset it on every run so the dataset always matches
    # the shape below exactly, rather than only backfilling on an empty table.
    org.upsell_rules.destroy_all

    trigger_service = services.find { |service| service.internal_name == "flu-jab" }
    suggested_service = services.find { |service| service.internal_name == "blood-pressure" }

    org.upsell_rules.create!(
      name: "Flu to blood pressure",
      trigger_service: trigger_service,
      suggested_service: suggested_service,
      frequency_type: "every_nth_customer",
      frequency_value: 3,
      visit_type: "any",
      cooldown_days: 30,
      active: true,
      priority: 0,
      upsell_templates_attributes: [
        {
          title: "While you're here...",
          description: "Add a quick blood pressure check to today's visit.",
          cta_text: "Add blood pressure check"
        }
      ]
    )

    puts "Seeded 1 upsell rule in org '#{org.name}'"

    # Spread walk-in queue and appointment data across the 5 days centred on today
    # (2 days either side) so day-navigation views have something to page through.
    # Wrapped in the org's own time zone so "today" here matches what the running
    # app computes for it (Org::BaseController wraps requests the same way) -
    # otherwise this seed's "today" data could land on the wrong day near midnight.
    Time.use_zone(org.time_zone) do
    day_offsets = (-2..2).to_a

    org.service_requests.destroy_all

    created_requests = 0

    day_offsets.each do |offset|
      date = Date.current + offset.days

      20.times do
        service = services.sample
        status =
          if offset.negative?
            %w[completed completed completed cancelled].sample
          elsif offset.zero?
            %w[waiting in_progress completed completed cancelled].sample
          else
            "waiting"
          end

        created_at = date.to_time.change(hour: rand(9..17), min: rand(0..59))

        attrs = {
          organization: org,
          service: service,
          first_name: Faker::Name.first_name.upcase,
          last_name: Faker::Name.last_name.upcase,
          dob: Faker::Date.birthday(min_age: 5, max_age: 85),
          postcode: Faker::Base.with_locale(:"en-GB") { Faker::Address.postcode.upcase },
          request_type: %w[immediate immediate immediate appointment].sample,
          status: status,
          queue_date: date,
          created_at: created_at,
          description: [ nil, Faker::Lorem.sentence(word_count: 5) ].sample,
          privacy_requested: [ false, false, false, true ].sample
        }

        case status
        when "in_progress"
          attrs[:called_at] = created_at + rand(2..15).minutes
        when "completed"
          called_at = created_at + rand(2..10).minutes
          attrs[:called_at] = called_at
          attrs[:completed_at] = called_at + rand(5..25).minutes
        end

        org.service_requests.create!(attrs)
        created_requests += 1
      end
    end

    puts "Seeded #{created_requests} service requests into org '#{org.name}' (#{day_offsets.first}..#{day_offsets.last} days around today)"

    org.appointments.destroy_all

    # Picks a random bookable time on `date` for `service`, ignoring same-day "already
    # passed" filtering (SlotAvailabilityService excludes those since it's meant for the
    # live booking UI, not backfilling seed data) - the model only rejects a `booked`
    # appointment_date in the past, never a specific time within today.
    random_bookable_time = lambda do |service, date|
      periods = (org.bookable_times || {})[date.strftime("%A").downcase]
      next nil if periods.blank?

      slot_minutes = service.estimated_duration
      period = periods.sample
      start_h, start_m = period["start"].split(":").map(&:to_i)
      end_h, end_m = period["end"].split(":").map(&:to_i)
      start_total = (start_h * 60) + start_m
      end_total = (end_h * 60) + end_m
      steps = (end_total - start_total) / slot_minutes
      next nil if steps < 1

      slot_start = start_total + (rand(steps) * slot_minutes)
      hour, minute = slot_start.divmod(60)
      format("%02d:%02d", hour, minute)
    end

    # Returns true if an appointment was created for `date`, false if this attempt
    # landed on an unbookable slot/day (e.g. the clinic is closed) and should be retried.
    create_random_appointment = lambda do |date|
      service = services.sample
      status = %w[booked booked booked booked cancelled no_show].sample

      first_name = Faker::Name.first_name.upcase
      last_name = Faker::Name.last_name.upcase

      attrs = {
        organization: org,
        service: service,
        first_name: first_name,
        last_name: last_name,
        dob: Faker::Date.birthday(min_age: 18, max_age: 85),
        postcode: Faker::Base.with_locale(:"en-GB") { Faker::Address.postcode.upcase },
        email: [ Faker::Internet.email(name: "#{first_name} #{last_name}"), nil ].sample,
        appointment_date: date,
        status: status,
        notes: [ nil, Faker::Lorem.sentence(word_count: 6) ].sample
      }

      time_str = random_bookable_time.call(service, date)
      next false if time_str.nil?

      attrs[:appointment_time] = Time.zone.parse("2000-01-01 #{time_str}")

      if status == "booked"
        appointment = org.appointments.build(attrs)
        appointment.save_with_slot_protection
      else
        attrs[:cancelled_at] = Time.current if status == "cancelled"
        attrs[:no_show_at] = Time.current if status == "no_show"

        org.appointments.create!(attrs).persisted?
      end
    end

    target_appointments = 100
    created_count = 0

    day_offsets.each do |offset|
      date = Date.current + offset.days
      day_created = 0
      attempts = 0

      while day_created < 20 && attempts < 200
        attempts += 1
        day_created += 1 if create_random_appointment.call(date)
      end

      created_count += day_created
    end

    # Some days may be closed (no bookable hours), so top up on the open days
    # until the total reaches the target instead of quietly falling short.
    bookable_offsets = day_offsets.select do |offset|
      day_key = (Date.current + offset.days).strftime("%A").downcase
      (org.bookable_times || {})[day_key].present?
    end

    top_up_attempts = 0
    while created_count < target_appointments && bookable_offsets.any? && top_up_attempts < 1000
      top_up_attempts += 1
      date = Date.current + bookable_offsets.sample.days
      created_count += 1 if create_random_appointment.call(date)
    end

    puts "Seeded #{created_count} appointments into org '#{org.name}' (#{day_offsets.first}..#{day_offsets.last} days around today)"
    end
  else
    puts "SKIP: no org found for #{dev_owner_email}"
  end
end
