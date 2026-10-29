# frozen_string_literal: true

module CalendarScoped
  extend ActiveSupport::Concern

  CALENDAR_SCOPES = %w[all selected].freeze

  included do
    attr_reader :calendar_scope

    validate :selected_calendars_present
    validate :calendars_belong_to_organization
    after_save :sync_requested_calendars
  end

  class_methods do
    def calendar_scoped_through(join_association, join_class:, foreign_key:)
      has_many join_association, dependent: :delete_all
      has_many :calendars, through: join_association

      define_singleton_method(:calendar_join_class) { join_class.constantize }
      define_singleton_method(:calendar_join_foreign_key) { foreign_key }
    end

    def all_calendars
      where.not(id: calendar_join_class.select(calendar_join_foreign_key))
    end

    def for_calendar(calendar)
      return all_calendars if calendar.nil?

      all_calendars.or(where(id: calendar_join_class.where(calendar_id: calendar.id).select(calendar_join_foreign_key)))
    end
  end

  def assign_calendars(scope:, ids:)
    @calendar_scope = CALENDAR_SCOPES.include?(scope.to_s) ? scope.to_s : "all"
    @requested_calendar_ids = @calendar_scope == "selected" ? Array(ids).compact_blank.map(&:to_i).uniq : []
  end

  def target_calendar_ids
    @requested_calendar_ids || calendar_ids
  end

  def all_calendars?
    target_calendar_ids.empty?
  end

  def applies_to?(calendar)
    all_calendars? || target_calendar_ids.include?(calendar&.id)
  end

  def specifically_for?(calendar)
    calendar.present? && target_calendar_ids.include?(calendar.id)
  end

  def calendar_label
    return "All calendars" if all_calendars?

    calendars.sort_by(&:name).map { |calendar| calendar.archived? ? "#{calendar.name} (archived)" : calendar.name }.join(", ")
  end

  def effective_calendar_scope
    calendar_scope.presence || (all_calendars? ? "all" : "selected")
  end

  private

  def selected_calendars_present
    return unless calendar_scope == "selected" && target_calendar_ids.empty?

    errors.add(:calendar_ids, "choose at least one calendar")
  end

  def calendars_belong_to_organization
    ids = target_calendar_ids
    return if ids.empty? || organization.nil?

    errors.add(:calendar_ids, "is not valid") unless organization.calendars.where(id: ids).count == ids.size
  end

  def sync_requested_calendars
    return if @requested_calendar_ids.nil?

    self.calendar_ids = @requested_calendar_ids
    @requested_calendar_ids = nil
  end
end
