# frozen_string_literal: true

class AuditLogJsonSearch
  FUZZY_THRESHOLD = 0.90

  def self.filter(scope, query, organizations_by_id: {})
    new(scope, query, organizations_by_id: organizations_by_id).filter
  end

  def initialize(scope, query, organizations_by_id: {})
    @scope = scope
    @query = query.to_s.strip.downcase
    @organizations_by_id = organizations_by_id
  end

  def filter
    return @scope if @query.blank?

    query_terms = @query.scan(/[[:alnum:]][[:alnum:]_.@-]*/)
    return Kaminari.paginate_array([]) if query_terms.empty?

    matching = @scope.select { |log| log_matches?(log, query_terms) }
    Kaminari.paginate_array(matching)
  end

  private

  def log_matches?(log, query_terms)
    text = searchable_text(log)
    return true if text.include?(@query)

    tokens = text.scan(/[[:alnum:]][[:alnum:]_.@-]*/).uniq
    query_terms.any? { |term| FuzzyMatch.new(tokens).find(term, threshold: FUZZY_THRESHOLD) }
  end

  def searchable_text(log)
    organization = @organizations_by_id[log.resolved_organization_id]

    {
      id: log.id,
      event_type: log.event_type,
      ip_address: log.ip_address,
      user_agent: log.user_agent,
      metadata: log.metadata,
      user: {
        id: log.user_id,
        first_name: log.user&.first_name,
        last_name: log.user&.last_name,
        email: log.user&.email
      },
      organization: {
        id: log.resolved_organization_id,
        name: organization&.name,
        slug: organization&.slug
      },
      resource: { type: log.resource_type, id: log.resource_id }
    }.to_json.downcase
  end
end
