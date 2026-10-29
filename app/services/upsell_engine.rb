# frozen_string_literal: true

class UpsellEngine
  # Returns { rule:, template:, customer_hash: } or nil if no rule qualifies.
  def self.evaluate(organization:, service:, customer_dob:, customer_first_name:, customer_last_name:)
    dob_known = customer_dob.present?
    customer_age = dob_known ? calculate_age(customer_dob) : nil
    customer_hash = build_hash(customer_dob, customer_first_name, customer_last_name)

    rules = organization.upsell_rules
      .plan_active
      .includes(:upsell_templates, :suggested_service)
      .where(trigger_service: service)
      .order(priority: :desc)

    rules.each do |rule|
      next unless date_eligible?(rule)
      next unless age_eligible?(rule, customer_age)
      next unless visit_eligible?(rule, customer_hash, dob_known: dob_known)
      next if dob_known && UpsellInteraction.recently_shown?(customer_hash: customer_hash, rule: rule)
      next unless frequency_eligible?(rule, organization)
      next unless within_limits?(rule)

      template = select_template(rule)
      next unless template.present?

      return { rule: rule, template: template, customer_hash: customer_hash }
    end

    nil
  end

  def self.calculate_age(dob)
    today = Date.current
    age = today.year - dob.year
    age -= 1 if today < dob + age.years
    age
  end

  def self.build_hash(dob, first_name, last_name)
    identity_parts = [ dob, first_name.to_s.downcase.strip, last_name.to_s.downcase.strip ].compact
    Digest::SHA256.hexdigest(identity_parts.join("|"))
  end

  def self.date_eligible?(rule)
    return false if rule.active_from.present? && Date.current < rule.active_from
    return false if rule.active_until.present? && Date.current > rule.active_until
    if rule.active_hours_start.present? && rule.active_hours_end.present?
      return false unless (rule.active_hours_start..rule.active_hours_end).cover?(Time.current.hour)
    end

    true
  end

  # Without a dob, customer_hash is name-only and too collision-prone to trust
  # for cross-visit identity, so first_visit/returning rules can't be verified.
  def self.visit_eligible?(rule, customer_hash, dob_known:)
    case rule.visit_type
    when "first_visit"
      dob_known && !UpsellInteraction.where(customer_hash: customer_hash, organization: rule.organization).exists?
    when "returning"
      dob_known && UpsellInteraction.where(customer_hash: customer_hash, organization: rule.organization).exists?
    else
      true
    end
  end

  # A nil age (no dob collected) only satisfies rules with no age bounds set.
  def self.age_eligible?(rule, age)
    return true if rule.min_age.blank? && rule.max_age.blank?
    return false if age.nil?
    return false if rule.min_age.present? && age < rule.min_age
    return false if rule.max_age.present? && age > rule.max_age

    true
  end

  def self.frequency_eligible?(rule, organization)
    counter = UpsellCounter.find_or_initialize_by(
      organization: organization,
      upsell_rule: rule,
      date: Date.current,
      hour: Time.current.hour
    )
    counter.total_eligible = (counter.total_eligible || 0) + 1
    counter.save!

    case rule.frequency_type
    when "every_nth_customer"
      counter.total_eligible % rule.frequency_value == 1
    when "percentage_based"
      rand(100) < rule.frequency_value
    else
      false
    end
  end

  def self.within_limits?(rule)
    return true if rule.daily_limit.nil? && rule.hourly_limit.nil?

    today_counters = rule.upsell_counters.where(date: Date.current)

    if rule.daily_limit
      return false if today_counters.sum(:conversion_count) >= rule.daily_limit
    end

    if rule.hourly_limit
      return false if today_counters.where(hour: Time.current.hour).sum(:conversion_count) >= rule.hourly_limit
    end

    true
  end

  def self.select_template(rule)
    templates = rule.upsell_templates.order(:id).to_a
    return nil if templates.empty?
    return templates.first if templates.one?

    stats = UpsellInteraction
      .where(upsell_template_id: templates.map(&:id))
      .group(:upsell_template_id, :outcome)
      .count

    return templates[exploration_index(templates.size)] if explore?

    templates.max_by do |template|
      shown = stats.select { |(template_id, _), _| template_id == template.id }.values.sum
      accepted = stats.fetch([ template.id, "accepted_immediate" ], 0) +
                 stats.fetch([ template.id, "accepted_appointment" ], 0)
      shown.positive? ? accepted.to_f / shown : exploration_tiebreak
    end
  end

  def self.explore?
    exploration_roll < 0.1
  end

  def self.exploration_roll
    rand
  end

  def self.exploration_index(size)
    (rand * size).floor
  end

  def self.exploration_tiebreak
    rand
  end
end
