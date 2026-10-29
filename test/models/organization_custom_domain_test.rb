require "test_helper"

class OrganizationCustomDomainTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create_personal_for!(users(:one))
  end

  test "accepts a valid custom_domain on Growth and normalizes it" do
    assert @organization.update(custom_domain: "WWW.Shop.Example.COM")
    assert_equal "shop.example.com", @organization.reload.custom_domain
  end

  test "rejects invalid custom_domain format" do
    assert_not @organization.update(custom_domain: "not a domain")
    assert_not @organization.update(custom_domain: "localhost")
    assert_not @organization.update(custom_domain: "http://shop.example.com")
  end

  test "enforces unique custom_domain" do
    other = Organization.create_personal_for!(users(:two))

    assert @organization.update(custom_domain: "shop.example.com")

    assert_not other.update(custom_domain: "shop.example.com")
    assert_includes other.errors[:custom_domain], "has already been taken"
  end

  test "clears domain cache when custom_domain changes" do
    @organization.update!(custom_domain: "old.example.com")
    Rails.cache.write("#{Organization::DOMAIN_ORG_CACHE_PREFIX}old.example.com", @organization.id)
    Rails.cache.write("#{Organization::DOMAIN_ORG_CACHE_PREFIX}new.example.com", 999)

    @organization.update!(custom_domain: "new.example.com")

    assert_nil Rails.cache.read("#{Organization::DOMAIN_ORG_CACHE_PREFIX}old.example.com")
    assert_nil Rails.cache.read("#{Organization::DOMAIN_ORG_CACHE_PREFIX}new.example.com")
  end

  test "find_id_by_custom_domain caches the organization id" do
    @organization.update!(custom_domain: "shop.example.com")

    assert_equal @organization.id, Organization.find_id_by_custom_domain("shop.example.com")
    assert_equal @organization.id, Rails.cache.read("#{Organization::DOMAIN_ORG_CACHE_PREFIX}shop.example.com")
  end
end
