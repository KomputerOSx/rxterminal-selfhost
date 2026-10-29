# frozen_string_literal: true

class AuditLogSearch
  SORT_COLUMNS = %w[created_at event_type ip_address].freeze
  RESOURCE_TYPES = %w[
    Organization User Service ServiceRequest Appointment Device Calendar UpsellRule Membership AuditLog
  ].freeze

  Result = Data.define(:audit_logs, :filters_applied, :matched_users, :sort_column, :sort_direction, :filter_params)

  def self.call(params, organization_id: nil)
    new(params, organization_id: organization_id).call
  end

  def self.organization_scope(organization_id)
    new(ActionController::Parameters.new, organization_id: organization_id).organization_scope
  end

  def initialize(params, organization_id: nil)
    @params = params
    @organization_id = organization_id&.to_i
    @matched_users = []
  end

  def call
    filters_applied = filter_params.values.any?(&:present?)

    unless filters_applied
      return Result.new(
        audit_logs: AuditLog.none.page(1),
        filters_applied: false,
        matched_users: [],
        sort_column: default_sort_column,
        sort_direction: default_sort_direction,
        filter_params: filter_params
      )
    end

    logs = scoped_logs

    if logs.is_a?(ActiveRecord::Relation)
      logs = logs.page(@params[:page]).per(100)
      AuditLogOrganizationResolver.preload!(logs)
    else
      logs = logs.page(@params[:page]).per(100)
    end

    Result.new(
      audit_logs: logs,
      filters_applied: true,
      matched_users: @matched_users,
      sort_column: sort_column,
      sort_direction: sort_direction,
      filter_params: filter_params
    )
  end

  def filter_params
    @filter_params ||= begin
      permitted = @params.permit(
        :user_search,
        :date_from,
        :date_to,
        :resource_type,
        :resource_id,
        :json_search,
        event_types: [],
        organization_ids: []
      ).to_h
      permitted.delete("organization_ids") if @organization_id.present?
      permitted
    end
  end

  def organization_scope
    apply_plan_retention(filter_organizations(AuditLog.all))
  end

  private

  def scoped_logs
    logs = AuditLog.includes(:user)
    logs = filter_event_types(logs)
    logs = filter_user_search(logs)
    logs = filter_date_range(logs)
    logs = filter_organizations(logs)
    logs = filter_resource(logs)
    logs = apply_sort(logs)
    apply_json_search(logs)
  end

  def filter_event_types(scope)
    event_types = Array(filter_params[:event_types]).reject(&:blank?)
    return scope if event_types.empty?

    scope.where(event_type: event_types)
  end

  def filter_user_search(scope)
    query = filter_params[:user_search].to_s.strip
    return scope if query.blank?

    @matched_users = match_users_for_search(query)
    scope.where(user_id: @matched_users.map(&:id).presence || [ -1 ])
  end

  def match_users_for_search(query)
    if @organization_id.present?
      member_ids = Membership.where(organization_id: @organization_id).pluck(:user_id)
      return [] if member_ids.empty?

      if query.match?(/\A\d+\z/)
        user = User.find_by(id: query.to_i)
        user && member_ids.include?(user.id) ? [ user ] : []
      elsif query.include?("@")
        user = User.find_by(email: query.downcase)
        user && member_ids.include?(user.id) ? [ user ] : []
      else
        needle = query.downcase
        User.where(id: member_ids).select { |user| user.email.include?(needle) }.first(20)
      end
    elsif query.match?(/\A\d+\z/)
      User.where(id: query.to_i).to_a
    elsif query.include?("@")
      user = User.find_by(email: query.downcase)
      user ? [ user ] : []
    else
      needle = query.downcase
      user_ids = AuditLog.where.not(user_id: nil).distinct.pluck(:user_id)
      User.where(id: user_ids).select { |user| user.email.include?(needle) }.first(20)
    end
  end

  def filter_date_range(scope)
    if filter_params[:date_from].present?
      from = Time.zone.parse(filter_params[:date_from])
      from = retention_cutoff if from && retention_cutoff && from < retention_cutoff
      scope = scope.where("created_at >= ?", from)
    end

    if filter_params[:date_to].present?
      scope = scope.where("created_at <= ?", Time.zone.parse(filter_params[:date_to]))
    end

    apply_plan_retention(scope)
  end

  def filter_organizations(scope)
    org_ids = if @organization_id.present?
      [ @organization_id ]
    else
      Array(filter_params[:organization_ids]).reject(&:blank?).map(&:to_i)
    end
    return scope if org_ids.empty?

    relation = scope.where(resource_type: "Organization", resource_id: org_ids)

    org_ids.each do |org_id|
      relation = relation.or(
        scope.where("metadata LIKE ?", "%\"organization_id\":#{org_id}%")
      )
    end

    AuditLogOrganizationResolver::RESOURCE_MODELS.each do |resource_type, model|
      resource_ids = model.where(organization_id: org_ids).pluck(:id)
      next if resource_ids.empty?

      relation = relation.or(
        scope.where(resource_type: resource_type, resource_id: resource_ids)
      )
    end

    relation
  end

  def filter_resource(scope)
    if filter_params[:resource_type].present?
      scope = scope.where(resource_type: filter_params[:resource_type])
    end

    if filter_params[:resource_id].present?
      scope = scope.where(resource_id: filter_params[:resource_id].to_i)
    end

    scope
  end

  def apply_sort(scope)
    return scope.order(created_at: :desc) unless scope.is_a?(ActiveRecord::Relation)

    scope.order(sort_column => sort_direction)
  end

  def apply_json_search(scope)
    query = filter_params[:json_search].to_s.strip
    return scope if query.blank?
    return scope unless scope.is_a?(ActiveRecord::Relation)

    records = scope.includes(:user).to_a
    AuditLogOrganizationResolver.preload!(records)
    organizations_by_id = records.filter_map(&:resolved_organization).index_by(&:id)

    AuditLogJsonSearch.filter(records, query, organizations_by_id: organizations_by_id)
  end

  def sort_column
    SORT_COLUMNS.include?(@params[:sort]) ? @params[:sort] : default_sort_column
  end

  def sort_direction
    @params[:direction] == "asc" ? "asc" : default_sort_direction
  end

  def default_sort_column
    "created_at"
  end

  def default_sort_direction
    "desc"
  end

  def apply_plan_retention(scope)
    return scope unless @organization_id.present?

    organization = Organization.find_by(id: @organization_id)
    return scope unless organization

    organization.audit_logs_scope(scope)
  end

  def retention_cutoff
    return @retention_cutoff if defined?(@retention_cutoff)

    @retention_cutoff = if @organization_id.present?
      organization = Organization.find_by(id: @organization_id)
      days = organization&.audit_log_retention_days
      days ? days.days.ago : nil
    end
  end
end
