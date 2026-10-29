# frozen_string_literal: true

module CalendarsHelper
  def calendar_color_dot(calendar, size: 12)
    content_tag(:span, "",
      class: "inline-block shrink-0 rounded-full border border-base-300",
      style: "width:#{size}px;height:#{size}px;background-color:#{calendar.color}")
  end
end
