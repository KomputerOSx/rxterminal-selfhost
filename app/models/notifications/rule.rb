module Notifications
  class Rule
    include Rails.application.routes.url_helpers

    attr_reader :actor, :resource, :organization, :metadata

    def initialize(actor:, resource:, organization:, metadata:)
      @actor = actor
      @resource = resource
      @organization = organization
      @metadata = metadata
    end

    def self.event_type
      raise NotImplementedError, "#{name} must define .event_type"
    end

    def self.category
      raise NotImplementedError, "#{name} must define .category"
    end

    def self.channels
      [ :in_app, :email ]
    end

    def recipients
      raise NotImplementedError, "#{self.class.name} must implement #recipients"
    end

    def title
      raise NotImplementedError, "#{self.class.name} must implement #title"
    end

    def body
      raise NotImplementedError, "#{self.class.name} must implement #body"
    end

    # Optional structured [label, value] pairs shown as a details list
    # alongside the body (e.g. a rounded table in the email, a definition
    # list in-app). Empty by default - most rules don't need this.
    def details
      []
    end

    # Path the notification links to, or nil for no click-through target.
    def url
      nil
    end

    private

    def actor_name
      return "Someone" unless actor

      [ actor.first_name, actor.last_name ].compact_blank.join(" ").presence || actor.email
    end

    def actor_only
      actor ? User.where(id: actor.id) : User.none
    end

    def organization_owners
      organization ? organization.owner_users : User.none
    end
  end
end
