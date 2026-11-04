# frozen_string_literal: true

module MailerHelper
  MAILER_HEADER_LOGO_STYLE = "display:block;height:36px;width:auto;margin:0 auto;border:0;"
  MAILER_POWERED_BY_LOGO_STYLE = "display:inline-block;height:12px;width:auto;vertical-align:middle;border:0;"

  def mailer_logo_image_tag(filename: MailerTheme::LOGO_FILENAME, style: MAILER_HEADER_LOGO_STYLE)
    logo_url = AppConfig.logo_url || (AppConfig.default_name? ? mailer_inline_logo_url(filename) : nil)

    if logo_url
      image_tag logo_url, alt: AppConfig.name, style: style
    elsif AppConfig.default_name? && (asset_path = mailer_logo_asset_path(filename))
      image_tag asset_path, alt: AppConfig.name, style: style
    else
      content_tag(:span, AppConfig.name,
                  style: "font-size:18px;font-weight:700;letter-spacing:0.04em;color:#{MailerTheme::HEADER_FOOTER_TEXT};")
    end
  end

  def mailer_website_url
    AppConfig.site_url
  end

  def mailer_privacy_policy_url
    "#{mailer_website_url}/privacy-policy"
  end

  def mailer_terms_url
    "#{mailer_website_url}/terms"
  end

  def mailer_website_domain
    mailer_website_url.sub(%r{\Ahttps?://}, "")
  end

  # Small open-source credit; links to the project, not to this install.
  def mailer_powered_by_html
    content_tag(:span, style: "color:#{MailerTheme::FOOTER_MUTED};font-size:12px;") do
      safe_join([ "Powered by ", link_to(AppConfig::DEFAULT_NAME, AppConfig::PROJECT_URL, style: "color:#{MailerTheme::FOOTER_MUTED};") ])
    end
  end

  def mailer_powered_by_text
    "Powered by #{AppConfig::DEFAULT_NAME} (#{AppConfig::PROJECT_URL})"
  end

  def mailer_contact_email
    AppConfig.support_email.to_s
  end

  def mailer_company_name
    AppConfig.operator_name
  end

  private

  def mailer_inline_logo_url(filename)
    return unless respond_to?(:attachments) && attachments[filename].present?

    attachments[filename].url
  end

  def mailer_logo_asset_path(filename)
    case filename
    when MailerTheme::LOGO_FILENAME then "RxTerminal-Title.png"
    when MailerTheme::LOGO_SMALL_FILENAME then "RxTerminal-Title-small.png"
    end
  end
end
