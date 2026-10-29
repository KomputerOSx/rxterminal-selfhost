# Extracts browser name/version, OS name/version and device type from a raw
# User-Agent string, without collapsing them into a lossy summary - callers
# get every field plus the original string back, so nothing is hidden.
class DeviceInfo
  Match = Struct.new(:name, :match, :version, keyword_init: true)

  BROWSERS = [
    Match.new(name: "Edge", match: /Edg\//, version: /Edg\/([\d.]+)/),
    Match.new(name: "Opera", match: /OPR\/|Opera/, version: /(?:OPR|Opera)[\/ ]([\d.]+)/),
    Match.new(name: "Samsung Internet", match: /SamsungBrowser/, version: /SamsungBrowser\/([\d.]+)/),
    Match.new(name: "Yandex Browser", match: /YaBrowser/, version: /YaBrowser\/([\d.]+)/),
    Match.new(name: "Chrome", match: /CriOS/, version: /CriOS\/([\d.]+)/),
    Match.new(name: "Firefox", match: /FxiOS/, version: /FxiOS\/([\d.]+)/),
    Match.new(name: "Firefox", match: /Firefox\//, version: /Firefox\/([\d.]+)/),
    Match.new(name: "Chrome", match: /Chrome\//, version: /Chrome\/([\d.]+)/),
    Match.new(name: "Safari", match: /Version\/.*Safari\//, version: /Version\/([\d.]+)/),
    Match.new(name: "Internet Explorer", match: /MSIE |Trident\//, version: /MSIE ([\d.]+)/)
  ].freeze

  OSES = [
    Match.new(name: "iOS", match: /iPhone|iPad|iPod/, version: /OS ([\d_]+) like Mac OS X/),
    Match.new(name: "Android", match: /Android/, version: /Android ([\d.]+)/),
    Match.new(name: "Chrome OS", match: /CrOS/, version: /CrOS \S+ ([\d.]+)/),
    Match.new(name: "Windows", match: /Windows/, version: /Windows NT ([\d.]+)/),
    Match.new(name: "macOS", match: /Mac OS X/, version: /Mac OS X ([\d_.]+)/),
    Match.new(name: "Linux", match: /Linux/, version: nil)
  ].freeze

  attr_reader :raw, :browser_name, :browser_version, :os_name, :os_version, :device_type

  def self.parse(user_agent)
    new(user_agent)
  end

  def initialize(user_agent)
    @raw = user_agent.to_s

    browser = BROWSERS.find { |b| b.match.match?(@raw) }
    @browser_name = browser&.name
    @browser_version = browser && extract(browser.version)

    os = OSES.find { |o| o.match.match?(@raw) }
    @os_name = os&.name
    @os_version = os && extract(os.version)&.tr("_", ".")

    @device_type = detect_device_type
  end

  def browser
    [ browser_name, browser_version ].compact_blank.join(" ").presence
  end

  def os
    [ os_name, os_version ].compact_blank.join(" ").presence
  end

  private

  def extract(regex)
    return nil if regex.nil? || @raw.blank?

    @raw[regex, 1]
  end

  def detect_device_type
    return nil if @raw.blank?
    return "Tablet" if @raw.match?(/iPad|Tablet/)
    return "Mobile" if @raw.match?(/Mobile|iPhone|Android/)

    "Desktop"
  end
end
