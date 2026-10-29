# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_12_120000) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "appointment_blocked_date_calendars", force: :cascade do |t|
    t.integer "appointment_blocked_date_id", null: false
    t.integer "calendar_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["appointment_blocked_date_id", "calendar_id"], name: "index_appointment_blocked_date_calendars_uniqueness", unique: true
    t.index ["appointment_blocked_date_id"], name: "idx_on_appointment_blocked_date_id_63323e0fd1"
    t.index ["calendar_id"], name: "index_appointment_blocked_date_calendars_on_calendar_id"
  end

  create_table "appointment_blocked_dates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "end_date", null: false
    t.integer "organization_id", null: false
    t.string "reason"
    t.string "source", default: "manual", null: false
    t.date "start_date", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "start_date", "end_date"], name: "index_appointment_blocked_dates_on_org_and_range"
    t.index ["organization_id"], name: "index_appointment_blocked_dates_on_organization_id"
  end

  create_table "appointment_opening_calendars", force: :cascade do |t|
    t.integer "appointment_opening_id", null: false
    t.integer "calendar_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["appointment_opening_id", "calendar_id"], name: "index_appointment_opening_calendars_uniqueness", unique: true
    t.index ["appointment_opening_id"], name: "index_appointment_opening_calendars_on_appointment_opening_id"
    t.index ["calendar_id"], name: "index_appointment_opening_calendars_on_calendar_id"
  end

  create_table "appointment_openings", force: :cascade do |t|
    t.json "bookable_times", default: {}, null: false
    t.datetime "created_at", null: false
    t.date "end_date", null: false
    t.string "name"
    t.integer "organization_id", null: false
    t.date "start_date", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "start_date", "end_date"], name: "index_appointment_openings_on_org_and_range"
    t.index ["organization_id"], name: "index_appointment_openings_on_organization_id"
  end

  create_table "appointments", force: :cascade do |t|
    t.date "appointment_date", null: false
    t.time "appointment_time", null: false
    t.string "booking_reference", null: false
    t.integer "calendar_id"
    t.text "cancellation_reason"
    t.datetime "cancelled_at"
    t.datetime "checked_in_at"
    t.datetime "created_at", null: false
    t.string "dob"
    t.string "email"
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.datetime "no_show_at"
    t.text "notes"
    t.integer "organization_id", null: false
    t.datetime "pii_redacted_at"
    t.string "postcode"
    t.integer "service_id", null: false
    t.integer "service_request_id"
    t.string "status", default: "booked", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_reference"], name: "index_appointments_on_booking_reference", unique: true
    t.index ["calendar_id"], name: "index_appointments_on_calendar_id"
    t.index ["organization_id", "appointment_date"], name: "index_appointments_on_organization_id_and_appointment_date"
    t.index ["organization_id", "service_id", "appointment_date"], name: "idx_on_organization_id_service_id_appointment_date_804e119a30"
    t.index ["organization_id", "status"], name: "index_appointments_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_appointments_on_organization_id"
    t.index ["pii_redacted_at"], name: "index_appointments_on_pii_redacted_at"
    t.index ["service_id"], name: "index_appointments_on_service_id"
    t.index ["service_request_id"], name: "index_appointments_on_service_request_id"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.string "ip_address"
    t.text "metadata"
    t.bigint "resource_id"
    t.string "resource_type"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["event_type"], name: "index_audit_logs_on_event_type"
    t.index ["resource_type", "resource_id"], name: "index_audit_logs_on_resource"
    t.index ["user_id", "event_type"], name: "index_audit_logs_on_user_id_and_event_type"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "billing_stripe_event_receipts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.datetime "received_at", null: false
    t.string "stripe_event_id", null: false
    t.datetime "updated_at", null: false
    t.index ["received_at"], name: "index_billing_stripe_event_receipts_on_received_at"
    t.index ["stripe_event_id"], name: "index_billing_stripe_event_receipts_on_stripe_event_id", unique: true
  end

  create_table "calendars", force: :cascade do |t|
    t.boolean "archived", default: false, null: false
    t.string "color", default: "#6366f1", null: false
    t.datetime "created_at", null: false
    t.boolean "is_default", default: false, null: false
    t.string "name", null: false
    t.integer "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "archived"], name: "index_calendars_on_organization_id_and_archived"
    t.index ["organization_id", "is_default"], name: "index_calendars_on_organization_id_and_is_default"
    t.index ["organization_id", "name"], name: "index_calendars_on_organization_id_and_name", unique: true
    t.index ["organization_id"], name: "index_calendars_on_organization_id"
  end

  create_table "devices", force: :cascade do |t|
    t.string "api_key_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "deactivated_at"
    t.string "device_id", null: false
    t.datetime "last_seen_at"
    t.string "name"
    t.integer "organization_id", null: false
    t.string "registered_ip"
    t.string "serial_number"
    t.string "status", default: "active", null: false
    t.integer "token_version", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["device_id"], name: "index_devices_on_device_id", unique: true
    t.index ["organization_id", "deactivated_at"], name: "index_devices_on_organization_id_and_deactivated_at"
    t.index ["organization_id"], name: "index_devices_on_organization_id"
    t.index ["status"], name: "index_devices_on_status"
  end

  create_table "email_campaign_recipients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "email_campaign_id", null: false
    t.string "error_message"
    t.datetime "failed_at"
    t.datetime "sent_at"
    t.datetime "skipped_at"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["email_campaign_id", "user_id"], name: "idx_email_campaign_recipients_unique", unique: true
    t.index ["email_campaign_id"], name: "index_email_campaign_recipients_on_email_campaign_id"
    t.index ["user_id"], name: "index_email_campaign_recipients_on_user_id"
  end

  create_table "email_campaigns", force: :cascade do |t|
    t.text "body_html", null: false
    t.string "category", default: "marketing", null: false
    t.datetime "created_at", null: false
    t.integer "created_by_id"
    t.integer "max_width", default: 600, null: false
    t.datetime "sent_at"
    t.string "status", default: "draft", null: false
    t.string "subject", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_email_campaigns_on_category"
    t.index ["created_at"], name: "index_email_campaigns_on_created_at"
    t.index ["created_by_id"], name: "index_email_campaigns_on_created_by_id"
    t.index ["status"], name: "index_email_campaigns_on_status"
  end

  create_table "feature_organization_accesses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.integer "feature_id", null: false
    t.integer "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_id", "organization_id"], name: "index_feature_org_accesses_on_feature_and_org", unique: true
    t.index ["feature_id"], name: "index_feature_organization_accesses_on_feature_id"
    t.index ["organization_id"], name: "index_feature_organization_accesses_on_organization_id"
  end

  create_table "features", force: :cascade do |t|
    t.boolean "applies_to_all_organizations", default: false, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "enabled", default: false, null: false
    t.string "key", null: false
    t.string "name", null: false
    t.boolean "org_opt_in_required", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_features_on_key", unique: true
  end

  create_table "identities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "provider", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["provider", "uid"], name: "index_identities_on_provider_and_uid", unique: true
    t.index ["user_id"], name: "index_identities_on_user_id"
  end

  create_table "membership_roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "granted_by_id"
    t.integer "membership_id", null: false
    t.integer "role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["granted_by_id"], name: "index_membership_roles_on_granted_by_id"
    t.index ["membership_id", "role_id"], name: "index_membership_roles_on_membership_id_and_role_id", unique: true
    t.index ["membership_id"], name: "index_membership_roles_on_membership_id"
    t.index ["role_id"], name: "index_membership_roles_on_role_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "organization_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
    t.index ["user_id", "organization_id"], name: "index_memberships_on_user_id_and_organization_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "notification_recipients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "dismissed_at"
    t.integer "notification_id", null: false
    t.datetime "read_at"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["notification_id", "user_id"], name: "idx_notification_recipients_unique", unique: true
    t.index ["notification_id"], name: "index_notification_recipients_on_notification_id"
    t.index ["user_id", "dismissed_at", "read_at"], name: "idx_notification_recipients_inbox"
    t.index ["user_id"], name: "index_notification_recipients_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.text "body", null: false
    t.string "category"
    t.datetime "created_at", null: false
    t.integer "created_by_id"
    t.text "details"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.datetime "withdrawn_at"
    t.index ["category"], name: "index_notifications_on_category"
    t.index ["created_at"], name: "index_notifications_on_created_at"
    t.index ["created_by_id"], name: "index_notifications_on_created_by_id"
    t.index ["withdrawn_at"], name: "index_notifications_on_withdrawn_at"
  end

  create_table "organization_invitations", force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "expires_at", null: false
    t.integer "invited_by_id"
    t.integer "organization_id", null: false
    t.datetime "revoked_at"
    t.integer "role_id", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["invited_by_id"], name: "index_organization_invitations_on_invited_by_id"
    t.index ["organization_id", "email"], name: "idx_org_invitations_pending_unique", unique: true, where: "accepted_at IS NULL AND revoked_at IS NULL"
    t.index ["organization_id"], name: "index_organization_invitations_on_organization_id"
    t.index ["role_id"], name: "index_organization_invitations_on_role_id"
    t.index ["token_digest"], name: "index_organization_invitations_on_token_digest", unique: true
  end

  create_table "organization_logos", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "decline_reason"
    t.integer "organization_id", null: false
    t.datetime "reviewed_at"
    t.integer "reviewed_by_id"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.integer "uploaded_by_id", null: false
    t.index ["organization_id", "status"], name: "index_organization_logos_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_organization_logos_on_organization_id"
    t.index ["reviewed_by_id"], name: "index_organization_logos_on_reviewed_by_id"
    t.index ["uploaded_by_id"], name: "index_organization_logos_on_uploaded_by_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "address_city"
    t.string "address_country"
    t.string "address_line1"
    t.string "address_line2"
    t.string "address_postal_code"
    t.string "address_state"
    t.string "appointment_booking_mode", default: "rolling", null: false
    t.integer "appointment_days_ahead", default: 14, null: false
    t.text "appointment_email_message"
    t.string "billing_address_city"
    t.string "billing_address_country"
    t.string "billing_address_line1"
    t.string "billing_address_line2"
    t.string "billing_address_postal_code"
    t.string "billing_address_state"
    t.string "billing_name"
    t.json "bookable_times", default: {}, null: false
    t.string "business_type"
    t.string "contact_email"
    t.string "contact_phone"
    t.datetime "created_at", null: false
    t.string "custom_domain"
    t.text "features"
    t.datetime "grandfathered_at"
    t.boolean "kiosk_collect_dob", default: true, null: false
    t.boolean "kiosk_collect_postcode", default: true, null: false
    t.string "kiosk_fallback_icon", default: "favorite", null: false
    t.integer "kiosk_featured_service_id"
    t.boolean "kiosk_show_appointments", default: true, null: false
    t.boolean "kiosk_show_featured_service", default: false, null: false
    t.boolean "kiosk_show_services", default: true, null: false
    t.string "kiosk_theme", default: "kiosk-default", null: false
    t.json "kiosk_theme_custom", default: {}, null: false
    t.string "name", null: false
    t.json "operating_hours", default: {}, null: false
    t.datetime "over_member_limit_at"
    t.datetime "pending_plan_change_at"
    t.string "pending_plan_key"
    t.integer "pending_price_cents"
    t.datetime "plan_reconciliation_applied_at"
    t.datetime "plan_reconciliation_blocking_at"
    t.json "plan_reconciliation_choices", default: {}, null: false
    t.datetime "plan_reconciliation_completed_at"
    t.string "portal_theme", default: "kiosk-default", null: false
    t.json "portal_theme_custom", default: {}, null: false
    t.string "postcode_region", default: "uk", null: false
    t.string "preferred_currency", default: "gbp", null: false
    t.boolean "require_appointment_email", default: false, null: false
    t.string "service_currency", default: "gbp", null: false
    t.string "slug", null: false
    t.datetime "slug_changed_at"
    t.string "stripe_subscription_schedule_id"
    t.string "time_zone", default: "UTC", null: false
    t.datetime "trial_ends_at"
    t.string "trial_plan_key"
    t.datetime "trial_used_at"
    t.datetime "updated_at", null: false
    t.index ["custom_domain"], name: "index_organizations_on_custom_domain", unique: true
    t.index ["kiosk_featured_service_id"], name: "index_organizations_on_kiosk_featured_service_id"
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "password_histories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "created_at"], name: "index_password_histories_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_password_histories_on_user_id"
  end

  create_table "password_reset_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "password_digest_snapshot", null: false
    t.string "request_ip"
    t.text "request_user_agent"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.integer "user_id", null: false
    t.index ["token_digest"], name: "index_password_reset_tokens_on_token_digest", unique: true
    t.index ["user_id", "expires_at", "used_at"], name: "idx_on_user_id_expires_at_used_at_c8aabddc42"
    t.index ["user_id"], name: "index_password_reset_tokens_on_user_id"
  end

  create_table "pay_charges", force: :cascade do |t|
    t.integer "amount", null: false
    t.integer "amount_refunded"
    t.integer "application_fee_amount"
    t.datetime "created_at", null: false
    t.string "currency"
    t.bigint "customer_id", null: false
    t.json "data"
    t.json "metadata"
    t.json "object"
    t.string "processor_id", null: false
    t.string "stripe_account"
    t.bigint "subscription_id"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["customer_id", "processor_id"], name: "index_pay_charges_on_customer_id_and_processor_id", unique: true
    t.index ["subscription_id"], name: "index_pay_charges_on_subscription_id"
  end

  create_table "pay_customers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "data"
    t.boolean "default"
    t.datetime "deleted_at", precision: nil
    t.json "object"
    t.bigint "owner_id"
    t.string "owner_type"
    t.string "processor", null: false
    t.string "processor_id"
    t.string "stripe_account"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id", "deleted_at"], name: "pay_customer_owner_index", unique: true
    t.index ["processor", "processor_id"], name: "index_pay_customers_on_processor_and_processor_id", unique: true
  end

  create_table "pay_merchants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "data"
    t.boolean "default"
    t.bigint "owner_id"
    t.string "owner_type"
    t.string "processor", null: false
    t.string "processor_id"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id", "processor"], name: "index_pay_merchants_on_owner_type_and_owner_id_and_processor"
  end

  create_table "pay_payment_methods", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.json "data"
    t.boolean "default"
    t.string "payment_method_type"
    t.string "processor_id", null: false
    t.string "stripe_account"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["customer_id", "processor_id"], name: "index_pay_payment_methods_on_customer_id_and_processor_id", unique: true
  end

  create_table "pay_subscriptions", force: :cascade do |t|
    t.decimal "application_fee_percent", precision: 8, scale: 2
    t.datetime "created_at", null: false
    t.datetime "current_period_end", precision: nil
    t.datetime "current_period_start", precision: nil
    t.bigint "customer_id", null: false
    t.json "data"
    t.datetime "ends_at", precision: nil
    t.json "metadata"
    t.boolean "metered"
    t.string "name", null: false
    t.json "object"
    t.string "pause_behavior"
    t.datetime "pause_resumes_at", precision: nil
    t.datetime "pause_starts_at", precision: nil
    t.string "payment_method_id"
    t.string "processor_id", null: false
    t.string "processor_plan", null: false
    t.integer "quantity", default: 1, null: false
    t.string "status", null: false
    t.string "stripe_account"
    t.datetime "trial_ends_at", precision: nil
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["customer_id", "processor_id"], name: "index_pay_subscriptions_on_customer_id_and_processor_id", unique: true
    t.index ["metered"], name: "index_pay_subscriptions_on_metered"
    t.index ["pause_starts_at"], name: "index_pay_subscriptions_on_pause_starts_at"
  end

  create_table "pay_webhooks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "event"
    t.string "event_type"
    t.string "processor"
    t.datetime "updated_at", null: false
  end

  create_table "permissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_permissions_on_key", unique: true
  end

  create_table "role_permissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "permission_id", null: false
    t.integer "role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["permission_id"], name: "index_role_permissions_on_permission_id"
    t.index ["role_id", "permission_id"], name: "index_role_permissions_on_role_id_and_permission_id", unique: true
    t.index ["role_id"], name: "index_role_permissions_on_role_id"
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "name", null: false
    t.boolean "permanent", default: false, null: false
    t.string "scope", default: "app", null: false
    t.datetime "updated_at", null: false
    t.index ["scope", "name"], name: "index_roles_on_scope_and_name", unique: true
  end

  create_table "service_requests", force: :cascade do |t|
    t.datetime "appointment_datetime"
    t.datetime "called_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "dob"
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.integer "organization_id", null: false
    t.datetime "pii_redacted_at"
    t.string "postcode"
    t.datetime "previous_called_at"
    t.string "previous_status"
    t.boolean "privacy_requested", default: false, null: false
    t.date "queue_date", null: false
    t.string "queue_number", null: false
    t.string "request_type", null: false
    t.integer "service_id", null: false
    t.string "status", default: "waiting", null: false
    t.string "submission_ip"
    t.datetime "updated_at", null: false
    t.index ["appointment_datetime"], name: "index_service_requests_on_appointment_datetime"
    t.index ["organization_id", "queue_number", "queue_date"], name: "index_service_requests_on_org_queue_number_and_date", unique: true
    t.index ["organization_id", "status", "created_at"], name: "idx_on_organization_id_status_created_at_cdbdab399d"
    t.index ["organization_id"], name: "index_service_requests_on_organization_id"
    t.index ["pii_redacted_at"], name: "index_service_requests_on_pii_redacted_at"
    t.index ["service_id"], name: "index_service_requests_on_service_id"
  end

  create_table "services", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.boolean "allows_immediate", default: true, null: false
    t.boolean "allows_private_consultation", default: false, null: false
    t.datetime "archived_at"
    t.integer "calendar_id"
    t.datetime "created_at", null: false
    t.text "delete_reason"
    t.datetime "deleted_at"
    t.integer "deleted_by_id"
    t.text "description"
    t.string "display_name", null: false
    t.integer "display_order", default: 0, null: false
    t.json "eligibility_requirements", default: {}, null: false
    t.integer "estimated_duration", null: false
    t.boolean "featured", default: false, null: false
    t.string "icon"
    t.string "internal_name", null: false
    t.integer "organization_id", null: false
    t.decimal "price", precision: 8, scale: 2
    t.boolean "requires_appointment", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["calendar_id"], name: "index_services_on_calendar_id"
    t.index ["deleted_by_id"], name: "index_services_on_deleted_by_id"
    t.index ["organization_id", "active", "display_order"], name: "index_services_on_organization_id_and_active_and_display_order"
    t.index ["organization_id", "archived_at"], name: "index_services_on_organization_id_and_archived_at"
    t.index ["organization_id", "deleted_at"], name: "index_services_on_organization_id_and_deleted_at"
    t.index ["organization_id", "internal_name"], name: "index_services_on_organization_id_and_internal_name_visible", unique: true, where: "deleted_at IS NULL"
    t.index ["organization_id"], name: "index_services_on_organization_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "ip_address"
    t.datetime "last_seen_at"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["expires_at"], name: "index_sessions_on_expires_at"
    t.index ["last_seen_at"], name: "index_sessions_on_last_seen_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "two_factor_challenges", force: :cascade do |t|
    t.integer "attempts", default: 0, null: false
    t.string "challenge_id", null: false
    t.string "code_digest"
    t.datetime "created_at", null: false
    t.string "delivery_method", default: "email", null: false
    t.datetime "expires_at", null: false
    t.string "ip_address"
    t.string "redirect_after"
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["challenge_id"], name: "index_two_factor_challenges_on_challenge_id", unique: true
    t.index ["delivery_method"], name: "index_two_factor_challenges_on_delivery_method"
    t.index ["user_id"], name: "index_two_factor_challenges_on_user_id"
  end

  create_table "upsell_counters", force: :cascade do |t|
    t.integer "book_later_count", default: 0, null: false
    t.integer "conversion_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.integer "decline_count", default: 0, null: false
    t.decimal "estimated_revenue", precision: 8, scale: 2, default: "0.0", null: false
    t.integer "hour"
    t.integer "organization_id", null: false
    t.integer "total_eligible", default: 0, null: false
    t.integer "total_triggered", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "upsell_rule_id", null: false
    t.index ["organization_id", "upsell_rule_id", "date", "hour"], name: "index_upsell_counters_unique", unique: true
    t.index ["organization_id"], name: "index_upsell_counters_on_organization_id"
    t.index ["upsell_rule_id"], name: "index_upsell_counters_on_upsell_rule_id"
  end

  create_table "upsell_interactions", force: :cascade do |t|
    t.boolean "accepted", default: false, null: false
    t.datetime "created_at", null: false
    t.string "customer_hash", null: false
    t.integer "organization_id", null: false
    t.string "outcome"
    t.datetime "updated_at", null: false
    t.integer "upsell_rule_id", null: false
    t.integer "upsell_template_id"
    t.index ["customer_hash", "upsell_rule_id"], name: "index_upsell_interactions_on_customer_hash_and_upsell_rule_id"
    t.index ["organization_id"], name: "index_upsell_interactions_on_organization_id"
    t.index ["upsell_rule_id"], name: "index_upsell_interactions_on_upsell_rule_id"
    t.index ["upsell_template_id"], name: "index_upsell_interactions_on_upsell_template_id"
  end

  create_table "upsell_rules", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.date "active_from"
    t.integer "active_hours_end"
    t.integer "active_hours_start"
    t.date "active_until"
    t.datetime "archived_at"
    t.integer "cooldown_days", default: 30, null: false
    t.datetime "created_at", null: false
    t.integer "daily_limit"
    t.string "frequency_type", null: false
    t.integer "frequency_value", null: false
    t.integer "hourly_limit"
    t.integer "max_age"
    t.integer "min_age"
    t.string "name", null: false
    t.integer "organization_id", null: false
    t.integer "priority", default: 0, null: false
    t.integer "suggested_service_id", null: false
    t.integer "trigger_service_id", null: false
    t.datetime "updated_at", null: false
    t.string "visit_type", default: "any", null: false
    t.index ["organization_id", "archived_at"], name: "index_upsell_rules_on_organization_id_and_archived_at"
    t.index ["organization_id", "trigger_service_id", "active"], name: "idx_on_organization_id_trigger_service_id_active_752396630c"
    t.index ["organization_id"], name: "index_upsell_rules_on_organization_id"
    t.index ["suggested_service_id"], name: "index_upsell_rules_on_suggested_service_id"
    t.index ["trigger_service_id"], name: "index_upsell_rules_on_trigger_service_id"
  end

  create_table "upsell_templates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "cta_text", null: false
    t.text "description"
    t.string "image_url"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "upsell_rule_id", null: false
    t.index ["upsell_rule_id"], name: "index_upsell_templates_on_upsell_rule_id"
  end

  create_table "user_roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "granted_by_id"
    t.integer "role_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["granted_by_id"], name: "index_user_roles_on_granted_by_id"
    t.index ["role_id"], name: "index_user_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_user_roles_on_user_id_and_role_id", unique: true
    t.index ["user_id"], name: "index_user_roles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "account_deletion_code_digest"
    t.datetime "account_deletion_code_sent_at"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "disabled_at"
    t.string "email", null: false
    t.integer "email_change_attempts", default: 0, null: false
    t.string "email_change_new_code_digest"
    t.datetime "email_change_new_confirmed_at"
    t.string "email_change_old_code_digest"
    t.datetime "email_change_old_confirmed_at"
    t.datetime "email_change_requested_at"
    t.json "email_preferences", default: {}, null: false
    t.integer "failed_login_attempts", default: 0, null: false
    t.string "first_name"
    t.json "known_user_agents", default: [], null: false
    t.string "last_name"
    t.datetime "last_sign_in_at"
    t.datetime "locked_until"
    t.json "notification_preferences", default: {}, null: false
    t.datetime "onboarding_completed_at"
    t.string "onboarding_step"
    t.string "owner_demotion_code_digest"
    t.datetime "owner_demotion_code_sent_at"
    t.string "ownership_promotion_code_digest"
    t.datetime "ownership_promotion_code_sent_at"
    t.string "password_digest", default: "", null: false
    t.datetime "totp_enabled_at"
    t.integer "totp_last_used_at"
    t.string "totp_secret"
    t.datetime "trial_granted_at"
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.index ["disabled_at"], name: "index_users_on_disabled_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["locked_until"], name: "index_users_on_locked_until"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "appointment_blocked_date_calendars", "appointment_blocked_dates"
  add_foreign_key "appointment_blocked_date_calendars", "calendars"
  add_foreign_key "appointment_blocked_dates", "organizations"
  add_foreign_key "appointment_opening_calendars", "appointment_openings"
  add_foreign_key "appointment_opening_calendars", "calendars"
  add_foreign_key "appointment_openings", "organizations"
  add_foreign_key "appointments", "calendars"
  add_foreign_key "appointments", "organizations"
  add_foreign_key "appointments", "service_requests"
  add_foreign_key "appointments", "services"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "calendars", "organizations"
  add_foreign_key "devices", "organizations"
  add_foreign_key "email_campaign_recipients", "email_campaigns"
  add_foreign_key "email_campaign_recipients", "users"
  add_foreign_key "email_campaigns", "users", column: "created_by_id"
  add_foreign_key "feature_organization_accesses", "features"
  add_foreign_key "feature_organization_accesses", "organizations"
  add_foreign_key "identities", "users"
  add_foreign_key "membership_roles", "memberships"
  add_foreign_key "membership_roles", "roles"
  add_foreign_key "membership_roles", "users", column: "granted_by_id"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "users"
  add_foreign_key "notification_recipients", "notifications"
  add_foreign_key "notification_recipients", "users"
  add_foreign_key "notifications", "users", column: "created_by_id"
  add_foreign_key "organization_invitations", "organizations"
  add_foreign_key "organization_invitations", "roles"
  add_foreign_key "organization_invitations", "users", column: "invited_by_id"
  add_foreign_key "organization_logos", "organizations"
  add_foreign_key "organization_logos", "users", column: "reviewed_by_id"
  add_foreign_key "organization_logos", "users", column: "uploaded_by_id"
  add_foreign_key "organizations", "services", column: "kiosk_featured_service_id", on_delete: :nullify
  add_foreign_key "password_histories", "users"
  add_foreign_key "password_reset_tokens", "users"
  add_foreign_key "pay_charges", "pay_customers", column: "customer_id"
  add_foreign_key "pay_charges", "pay_subscriptions", column: "subscription_id"
  add_foreign_key "pay_payment_methods", "pay_customers", column: "customer_id"
  add_foreign_key "pay_subscriptions", "pay_customers", column: "customer_id"
  add_foreign_key "role_permissions", "permissions"
  add_foreign_key "role_permissions", "roles"
  add_foreign_key "service_requests", "organizations"
  add_foreign_key "service_requests", "services"
  add_foreign_key "services", "calendars"
  add_foreign_key "services", "organizations"
  add_foreign_key "services", "users", column: "deleted_by_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "two_factor_challenges", "users"
  add_foreign_key "upsell_counters", "organizations"
  add_foreign_key "upsell_counters", "upsell_rules"
  add_foreign_key "upsell_interactions", "organizations"
  add_foreign_key "upsell_interactions", "upsell_rules"
  add_foreign_key "upsell_interactions", "upsell_templates"
  add_foreign_key "upsell_rules", "organizations"
  add_foreign_key "upsell_rules", "services", column: "suggested_service_id"
  add_foreign_key "upsell_rules", "services", column: "trigger_service_id"
  add_foreign_key "upsell_templates", "upsell_rules"
  add_foreign_key "user_roles", "roles"
  add_foreign_key "user_roles", "users"
  add_foreign_key "user_roles", "users", column: "granted_by_id"
end
