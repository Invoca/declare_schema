# frozen_string_literal: true

require_relative 'raw_html_string'

module HoboFields
  module Types
    class HtmlString < RawHtmlString
      HoboFields.register_type(:html, self)
    end
  end
end
