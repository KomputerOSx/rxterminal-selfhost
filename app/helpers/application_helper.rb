module ApplicationHelper
  include MailerHelper

  # Only icons that render in Material Symbols Outlined (some metadata names like
  # "discount" exist in Google's catalog but are not in the Outlined font file).
  MATERIAL_ICON_GROUPS = {
    "Medical & health" => %w[
      medical_services local_pharmacy stethoscope syringe pill medication medication_liquid vaccines
      bloodtype monitor_heart favorite emergency healing health_and_safety water_drop radiology
      weight child_care accessible coronavirus masks elderly woman pregnancy
      pediatrics dermatology immunology ophthalmology cardiology neurology gastroenterology orthopedics
      urology pulmonology endocrinology nephrology microbiology spa ecg_heart personal_injury
      medical_information emergency_home sick clinical_notes biotech science dentistry vital_signs
      symptoms medical_mask pill_off blood_pressure wheelchair_pickup assist_walker clean_hands sanitizer
      thermometer
    ],
    "People & social" => %w[
      person group groups person_add person_remove face mood sentiment_satisfied
      sentiment_dissatisfied thumb_up thumb_down handshake diversity_3 diversity_1 family_restroom wc
      man woman boy girl supervisor_account manage_accounts account_circle badge
      workspace_premium volunteer_activism celebration cake favorite loyalty redeem card_membership
    ],
    "Communication" => %w[
      mail inbox send drafts mark_email_read mark_email_unread contact_mail contact_phone
      call phone_in_talk sms chat forum comment support_agent headset_mic
      record_voice_over campaign notifications notifications_active notifications_off rss_feed share reply
      forward alternate_email wifi_calling video_call videocam mic mic_off speaker_notes
      translate language
    ],
    "Business & office" => %w[
      corporate_fare apartment domain store storefront work work_history assignment
      assignment_ind task task_alt checklist fact_check description article note_alt
      edit_note inventory inventory_2 warehouse request_quote price_check payments attach_money
      account_balance account_balance_wallet credit_card savings receipt receipt_long point_of_sale sell
      shopping_bag leaderboard analytics bar_chart pie_chart trending_up trending_down dashboard
      space_dashboard hub gavel policy admin_panel_settings
    ],
    "Shopping & retail" => %w[
      shopping_cart shopping_bag shopping_basket store storefront local_mall sell loyalty
      redeem card_membership percent_discount percent price_check request_quote inventory_2 package_2
      local_shipping takeout_dining receipt_long point_of_sale payments qr_code_scanner barcode_scanner
    ],
    "Food & drink" => %w[
      restaurant menu_book local_dining lunch_dining dinner_dining breakfast_dining brunch_dining ramen_dining
      rice_bowl soup_kitchen local_pizza local_cafe coffee emoji_food_beverage bakery_dining icecream
      cake liquor wine_bar local_bar fastfood kebab_dining set_meal egg
      egg_alt nutrition grocery kitchen blender microwave outdoor_grill cookie
    ],
    "Travel & transport" => %w[
      directions_car directions_bus directions_railway directions_subway directions_boat flight flight_takeoff flight_land
      train tram subway two_wheeler electric_scooter electric_car local_taxi car_rental
      commute hail map explore near_me my_location location_on location_city
      pin_drop route navigation signpost luggage beach_access landscape hiking
      kayaking sailing surfing hotel cottage villa cabin castle
      temple_buddhist mosque church
    ],
    "Home & places" => %w[
      home house cottage apartment villa cabin castle location_city
      location_on pin_drop map explore park yard grass forest
      water waves beach_access balcony door_front door_back garage fence
      roofing foundation holiday_village real_estate_agent meeting_room bed bathtub shower
      chair weekend light lightbulb thermostat ac_unit heat_pump fireplace
      local_laundry_service
    ],
    "Technology" => %w[
      computer desktop_windows tablet mobile devices memory storage cloud
      cloud_upload cloud_download cloud_sync wifi wifi_off router settings settings_applications
      tune build code terminal data_object database api integration_instructions
      developer_board usb cable bluetooth nfc qr_code qr_code_2 qr_code_scanner
      fingerprint security vpn_key lock lock_open smart_toy robot_2 precision_manufacturing
    ],
    "Media & entertainment" => %w[
      movie theaters live_tv tv radio music_note library_music headphones
      podcasts play_circle pause_circle stop_circle skip_next skip_previous fast_forward fast_rewind
      volume_up volume_off mic photo_camera photo_library image imagesmode palette
      brush draw wand_stars colors celebration sports_esports casino toys
      extension interests theater_comedy festival
    ],
    "Education & learning" => %w[
      school menu_book book library_books auto_stories history_edu science biotech
      calculate functions psychology quiz assignment assignment_turned_in grading
      groups cast_for_education model_training workspace_premium emoji_objects backpack edit_note draw
      architecture
    ],
    "Sports & fitness" => %w[
      fitness_center sports_soccer sports_basketball sports_tennis sports_golf sports_baseball sports_football sports_hockey
      sports_volleyball sports_cricket sports_mma sports_martial_arts sports_gymnastics sports_handball pool directions_run
      directions_walk hiking kayaking surfing sailing skateboarding snowboarding downhill_skiing
      self_improvement monitor_weight exercise
    ],
    "Nature & animals" => %w[
      pets cruelty_free eco energy_savings_leaf compost recycling water_drop waves
      wb_sunny partly_cloudy_day thunderstorm ac_unit air forest park yard
      grass local_florist spa pest_control bug_report hive nature nature_people
      landscape filter_vintage
    ],
    "Tools & construction" => %w[
      build construction handyman hardware home_repair_service plumbing electrical_services carpenter
      engineering precision_manufacturing factory warehouse agriculture grass yard fence
      roofing foundation format_paint brush content_cut straighten square_foot design_services
      architecture draw rule
    ],
    "Time & calendar" => %w[
      schedule timer hourglass_top hourglass_bottom today calendar_today calendar_month event
      event_available event_busy event_note date_range history update pending pending_actions
      alarm alarm_on alarm_off snooze more_time av_timer timelapse schedule_send
    ],
    "Security & privacy" => %w[
      lock lock_open key vpn_key password shield verified_user admin_panel_settings
      security privacy_tip gpp_maybe gpp_bad policy fingerprint visibility visibility_off
      no_encryption encrypted report warning dangerous error check_circle cancel
      block do_not_disturb_on remove_moderator person_off
    ],
    "General & status" => %w[
      star star_rate bolt info help notifications home public
      language check close add remove edit delete
      save download upload search filter_list sort refresh sync
      autorenew settings more_horiz more_vert menu apps dashboard open_in_new
      link content_copy print share bookmark bookmarks flag label
      fiber_new verified done_all priority_high low_priority circle adjust
    ]
  }.freeze

  def material_icon_groups
    MATERIAL_ICON_GROUPS
  end

  def material_icon(name, size: 24, **options)
    classes = options.delete(:class).to_s
    tag.span(
      name,
      class: [ "material-symbols-outlined", classes ].compact_blank.join(" "),
      style: "font-size:#{size}px;line-height:1",
      **options
    )
  end

  # Initials for the avatar circle: first letters of first/last name,
  # falling back to the first letter of the email.
  def user_initials(user)
    initials = [ user.first_name, user.last_name ].compact_blank.map { |n| n[0] }.join
    (initials.presence || user.email[0]).upcase
  end

  # Sortable column header link.
  # Toggles direction when already sorting by this column; defaults to asc on first click.
  def sort_link(label, column, current_sort:, current_dir:, turbo_frame: nil)
    active    = current_sort == column
    next_dir  = active && current_dir == "asc" ? "desc" : "asc"
    icon_name = active ? (current_dir == "asc" ? "arrow_upward" : "arrow_downward") : "unfold_more"
    icon_cls  = active ? "opacity-80" : "opacity-30"
    link_data = turbo_frame.present? ? { turbo_frame: turbo_frame } : {}

    link_to(request.query_parameters.merge(sort: column, direction: next_dir),
            class: "flex items-center gap-0.5 hover:text-base-content",
            data: link_data) do
      safe_join([
        content_tag(:span, label),
        content_tag(:span, icon_name,
                    class: "material-symbols-outlined #{icon_cls}",
                    style: "font-size:14px;line-height:1")
      ])
    end
  end
  # Returns a styled paragraph tag with the error message(s) if a field has errors
  def field_errors(object, field)
    return if object.nil? || !object.respond_to?(:errors) || object.errors[field].empty?

    content_tag(:p, class: "text-error text-xs mt-1 font-medium") do
      object.errors[field].to_sentence.capitalize
    end
  end

  # Returns the dynamic classes for input fields when they have validation errors
  def error_class_for(object, field, base_class = "")
    return base_class if object.nil? || !object.respond_to?(:errors) || object.errors[field].empty?
    "#{base_class} error"
  end

  SEARCHABLE_SELECT_MIN_OPTIONS = 8
  SEARCHABLE_SELECT_MIN_SERVICE_OPTIONS = 2
  SEARCHABLE_SELECT_MIN_CALENDAR_OPTIONS = 4
  OPTIONS_FILTER_MIN_UPSELL_RULES = 4

  def searchable_select_data(option_count:, data: {}, min: SEARCHABLE_SELECT_MIN_OPTIONS, force: false)
    result = data.dup
    return result unless force || option_count.to_i >= min

    controllers = Array(result[:controller].to_s.split(/\s+/)).reject(&:blank?)
    controllers << "searchable-select" unless controllers.include?("searchable-select")
    result[:controller] = controllers.join(" ")
    result[:searchable_select_min_options_value] = min
    result
  end

  def service_select_data(data: {}, option_count: 0)
    searchable_select_data(
      option_count: option_count,
      data: data,
      min: SEARCHABLE_SELECT_MIN_SERVICE_OPTIONS
    )
  end

  def calendar_select_data(data: {}, option_count: 0)
    searchable_select_data(
      option_count: option_count,
      data: data,
      min: SEARCHABLE_SELECT_MIN_CALENDAR_OPTIONS
    )
  end

  def options_filter_enabled?(item_count, min: SEARCHABLE_SELECT_MIN_OPTIONS)
    item_count.to_i >= min
  end

  def service_options_filter_enabled?(item_count)
    options_filter_enabled?(item_count, min: SEARCHABLE_SELECT_MIN_SERVICE_OPTIONS)
  end

  def upsell_rule_options_filter_enabled?(item_count)
    options_filter_enabled?(item_count, min: OPTIONS_FILTER_MIN_UPSELL_RULES)
  end

  def form_label_text(label, tooltips: false, tip: nil, required: false)
    text = required ? "#{label} *" : label

    content_tag(:span, class: "label-text inline-flex items-center gap-1") do
      safe_join([
        text,
        (tooltips && tip.present? ? render(partial: "shared/form_field_tooltip", locals: { text: tip }) : nil)
      ].compact)
    end
  end

  def form_section_heading(title, tooltips: false, tip: nil)
    content_tag(:h2, class: "text-lg font-semibold flex items-center gap-1.5") do
      safe_join([
        title,
        (tooltips && tip.present? ? render(partial: "shared/form_field_tooltip", locals: { text: tip }) : nil)
      ].compact)
    end
  end

  def form_option_label(label, tooltips: false, tip: nil)
    content_tag(:span, class: "text-sm font-medium inline-flex items-center gap-1") do
      safe_join([
        label,
        (tooltips && tip.present? ? render(partial: "shared/form_field_tooltip", locals: { text: tip }) : nil)
      ].compact)
    end
  end

  def form_subsection_label(label, tooltips: false, tip: nil)
    content_tag(:span, class: "text-sm font-medium inline-flex items-center gap-1") do
      safe_join([
        label,
        (tooltips && tip.present? ? render(partial: "shared/form_field_tooltip", locals: { text: tip }) : nil)
      ].compact)
    end
  end

  def can_manage_org_members?
    can_remove_org_members? || can_promote_org_members? || can_promote_to_owner? || can_demote_owner?
  end

  def can_remove_org_members?
    current_user.has_permission?("app.members.remove", organization: Current.organization)
  end

  def can_promote_org_members?
    current_user.has_permission?("app.members.promote", organization: Current.organization)
  end

  def can_promote_to_owner?
    current_user.has_permission?("app.members.promote_owner", organization: Current.organization)
  end

  def can_demote_owner?
    current_user.has_permission?("app.members.demote_owner", organization: Current.organization)
  end

  def org_switcher_status_badge(organization)
    if organization.locked?
      tag.span("Locked", class: "badge badge-error badge-xs shrink-0")
    elsif organization.past_due?
      tag.span("Payment due", class: "badge badge-warning badge-xs shrink-0")
    elsif organization.on_trial?
      days = organization.trial_days_remaining
      label = days == 1 ? "1 day left" : "#{days} days left"
      tag.span(label, class: "badge badge-info badge-xs shrink-0")
    end
  end
end
