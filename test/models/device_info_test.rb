require "test_helper"

class DeviceInfoTest < ActiveSupport::TestCase
  test "parses browser and OS name and version for desktop Chrome on macOS" do
    info = DeviceInfo.parse("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.129 Safari/537.36")

    assert_equal "Chrome", info.browser_name
    assert_equal "120.0.6099.129", info.browser_version
    assert_equal "Chrome 120.0.6099.129", info.browser
    assert_equal "macOS", info.os_name
    assert_equal "10.15.7", info.os_version
    assert_equal "macOS 10.15.7", info.os
    assert_equal "Desktop", info.device_type
  end

  test "parses an iPhone Safari user agent as mobile iOS with version" do
    info = DeviceInfo.parse("Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1")

    assert_equal "Safari", info.browser_name
    assert_equal "17.1", info.browser_version
    assert_equal "iOS", info.os_name
    assert_equal "17.1", info.os_version
    assert_equal "Mobile", info.device_type
  end

  test "parses an Android Chrome user agent as mobile" do
    info = DeviceInfo.parse("Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.144 Mobile Safari/537.36")

    assert_equal "Chrome", info.browser_name
    assert_equal "Android", info.os_name
    assert_equal "14", info.os_version
    assert_equal "Mobile", info.device_type
  end

  test "parses a Windows Edge user agent, not misreported as Chrome" do
    info = DeviceInfo.parse("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.2210.91")

    assert_equal "Edge", info.browser_name
    assert_equal "120.0.2210.91", info.browser_version
    assert_equal "Windows", info.os_name
    assert_equal "10.0", info.os_version
  end

  test "parses a Firefox on Linux user agent" do
    info = DeviceInfo.parse("Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0")

    assert_equal "Firefox", info.browser_name
    assert_equal "120.0", info.browser_version
    assert_equal "Linux", info.os_name
    assert_nil info.os_version
  end

  test "os falls back to just the name when no version pattern is found (Linux)" do
    info = DeviceInfo.parse("Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0")

    assert_equal "Linux", info.os
    assert_nil info.os_version
  end

  test "browser falls back to just the name when no version pattern is found (legacy IE)" do
    info = DeviceInfo.parse("Mozilla/5.0 (Windows NT 10.0; WOW64; Trident/7.0; rv:11.0) like Gecko")

    assert_equal "Internet Explorer", info.browser
    assert_nil info.browser_version
  end

  test "returns just the name when the user agent has no recognizable content at all" do
    info = DeviceInfo.parse("Firefox/120.0")

    assert_equal "Firefox 120.0", info.browser
    assert_nil info.os
  end

  test "returns nils for blank or unrecognized user agents, keeping the raw string" do
    blank = DeviceInfo.parse(nil)
    assert_nil blank.browser
    assert_nil blank.os
    assert_nil blank.device_type
    assert_equal "", blank.raw

    unknown = DeviceInfo.parse("SomeCustomClient/1.0")
    assert_nil unknown.browser
    assert_nil unknown.os
    assert_equal "SomeCustomClient/1.0", unknown.raw
  end
end
