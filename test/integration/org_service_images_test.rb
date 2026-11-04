# frozen_string_literal: true

require "test_helper"

class OrgServiceImagesTest < ActionDispatch::IntegrationTest
  PNG_BYTES = [ "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000d49444154789c6360000002000001e221bc330000000049454e44ae426082" ].pack("H*")

  setup do
    @owner = users(:one)
    @organization = Organization.create_personal_for!(@owner)
    @service = @organization.services.create!(
      internal_name: "flu-jab", display_name: "Flu Jab", estimated_duration: 15,
      allows_immediate: true, requires_appointment: true, icon: "vaccines"
    )
    @organization.update_feature!(:online_appointment_booking, enabled: true)
    post login_path, params: { email: @owner.email, password: "password123" }
  end

  def upload(filename: "flu.png", type: "image/png", bytes: PNG_BYTES)
    Rack::Test::UploadedFile.new(StringIO.new(bytes), type, original_filename: filename)
  end

  test "an image can be uploaded when editing a service" do
    patch org_service_path(@service), params: { service: { image: upload } }

    assert_redirected_to org_service_path(@service)
    assert @service.reload.image.attached?
    assert_includes AuditLog.where(event_type: :service_updated).last.metadata["changed_fields"], "image"
  end

  test "an image can be uploaded when creating a service" do
    post org_services_path, params: { service: {
      internal_name: "bp", display_name: "Blood pressure", estimated_duration: 10,
      allows_immediate: true, icon: "monitor_heart", image: upload
    } }

    assert @organization.services.find_by!(internal_name: "bp").image.attached?
  end

  test "a non-image or oversized file is rejected" do
    patch org_service_path(@service), params: { service: { image: upload(filename: "x.svg", type: "image/svg+xml", bytes: "<svg/>") } }
    assert_response :unprocessable_entity
    assert_match "must be a PNG, JPEG, GIF, or WebP file", response.body
    assert_not @service.reload.image.attached?

    big = upload(bytes: PNG_BYTES + ("x" * Service::MAX_IMAGE_SIZE))
    patch org_service_path(@service), params: { service: { image: big } }
    assert_response :unprocessable_entity
    assert_match "must be smaller than 5 MB", response.body
    assert_not @service.reload.image.attached?
  end

  test "the image can be replaced and removed" do
    @service.image.attach(io: StringIO.new(PNG_BYTES), filename: "old.png", content_type: "image/png")
    old_blob = @service.image.blob_id

    patch org_service_path(@service), params: { service: { image: upload(filename: "new.png") } }
    assert_not_equal old_blob, @service.reload.image.blob_id

    patch org_service_path(@service), params: { service: { display_name: "Flu Jab", remove_image: "1" } }
    assert_not @service.reload.image.attached?
  end

  test "saving without touching the image keeps it" do
    @service.image.attach(io: StringIO.new(PNG_BYTES), filename: "old.png", content_type: "image/png")

    patch org_service_path(@service), params: { service: { display_name: "Flu Jab (new)" } }

    assert @service.reload.image.attached?
  end

  test "the form shows the current image and a remove option" do
    @service.image.attach(io: StringIO.new(PNG_BYTES), filename: "old.png", content_type: "image/png")

    get edit_org_service_path(@service)

    assert_response :success
    assert_select "input[type=file][name='service[image]']"
    assert_select "input[type=checkbox][name='service[remove_image]']"
  end

  test "customers see the image on the public portal in place of the icon" do
    @service.image.attach(io: StringIO.new(PNG_BYTES), filename: "flu.png", content_type: "image/png")
    delete session_path

    get root_path
    assert_response :success
    assert_select "img[alt=?]", "Flu Jab"
  end

  test "a service without an image still shows its icon" do
    delete session_path

    get root_path
    assert_response :success
    assert_select "img[alt=?]", "Flu Jab", count: 0
  end

  test "the kiosk service card shows the image in the round tile, else the icon" do
    html = ApplicationController.render(partial: "kiosk/services/service_card", locals: { service: @service, preview: true })
    assert_includes html, "vaccines"
    assert_no_match(/<img/, html)

    @service.image.attach(io: StringIO.new(PNG_BYTES), filename: "flu.png", content_type: "image/png")
    html = ApplicationController.render(partial: "kiosk/services/service_card", locals: { service: @service.reload, preview: true })
    assert_match(/<img[^>]*alt=""/, html)
    assert_no_match(/vaccines/, html)
  end

  test "an unsaved rejected upload is never rendered" do
    service = @organization.services.build(internal_name: "x", display_name: "X", estimated_duration: 5, icon: "vaccines")
    service.image.attach(io: StringIO.new("<svg/>"), filename: "x.svg", content_type: "image/svg+xml")

    assert_not service.valid?
    assert_not ApplicationController.helpers.service_image?(service)
  end

  test "without libvips the original image is served instead of a resized variant" do
    @service.image.attach(io: StringIO.new(PNG_BYTES), filename: "flu.png", content_type: "image/png")
    delete session_path

    ImageProcessingSupport.stub :vips?, false do
      get root_path
    end

    src = css_select("img[alt='Flu Jab']").first["src"]
    assert_match %r{/rails/active_storage/blobs/}, src
    assert_no_match %r{representations}, src

    get src
    3.times { follow_redirect! if response.redirect? }
    assert_response :success
    assert_equal "image/png", response.media_type
  end

  test "with libvips a resized variant is requested" do
    @service.image.attach(io: StringIO.new(PNG_BYTES), filename: "flu.png", content_type: "image/png")
    delete session_path

    ImageProcessingSupport.stub :vips?, true do
      get root_path
    end

    assert_match %r{representations}, css_select("img[alt='Flu Jab']").first["src"]
  end

  test "the resized image is actually generated and served (needs libvips)" do
    begin
      require "vips"
    rescue LoadError
      skip "libvips is not installed here; CI and the Docker image have it"
    end

    @service.image.attach(io: StringIO.new(PNG_BYTES), filename: "flu.png", content_type: "image/png")
    delete session_path
    get root_path
    src = css_select("img[alt='Flu Jab']").first["src"]

    get src
    3.times { follow_redirect! if response.redirect? }

    assert_response :success
    assert_match(%r{\Aimage/}, response.media_type)
  end
end
