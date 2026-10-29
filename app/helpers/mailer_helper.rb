# frozen_string_literal: true

module MailerHelper
  MAILER_HEADER_LOGO_STYLE = "display:block;height:36px;width:auto;margin:0 auto;border:0;"
  MAILER_POWERED_BY_LOGO_STYLE = "display:inline-block;height:12px;width:auto;vertical-align:middle;border:0;"

  def mailer_logo_image_tag(filename: MailerTheme::LOGO_FILENAME, style: MAILER_HEADER_LOGO_STYLE)
    logo_url = mailer_inline_logo_url(filename)

    if logo_url
      image_tag logo_url, alt: "RxTerminal", style: style
    elsif (asset_path = mailer_logo_asset_path(filename))
      image_tag asset_path, alt: "RxTerminal", style: style
    else
      content_tag(:span, "RxTerminal",
                  style: "font-size:18px;font-weight:700;letter-spacing:0.04em;color:#{MailerTheme::HEADER_FOOTER_TEXT};")
    end
  end

  def mailer_website_url
    "https://rxterminal.co.uk"
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

  def mailer_powered_by_html
    safe_join([
      content_tag(:span, "Powered by ",
                  style: "color:#{MailerTheme::FOOTER_MUTED};font-size:12px;vertical-align:middle;"),
      link_to(mailer_website_url,
              style: "text-decoration:none;vertical-align:middle;display:inline-block;line-height:0;") do
        mailer_logo_image_tag(filename: MailerTheme::LOGO_SMALL_FILENAME, style: MAILER_POWERED_BY_LOGO_STYLE)
      end
    ])
  end

  def mailer_powered_by_text
    "Powered by RxTerminal (#{mailer_website_url})"
  end

  def mailer_contact_email
    "contact@strixon.co.uk"
  end

  def mailer_company_name
    "Strixon Ltd"
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
