# frozen_string_literal: true

require_relative 'raw_markdown_string'

module HoboFields
  module Types
    class MarkdownString < RawMarkdownString

      include SanitizeHtml

      HoboFields.register_type(:markdown, self)

      @@markdown_class = case
        when defined?(RDiscount)
          RDiscount
        when defined?(Kramdown)
          Kramdown::Document
        when defined?(Maruku)
          Maruku
        when defined?(Markdown)
          Markdown
        else
          raise ArgumentError, "must require RDiscount, Kramdown, Maruku, or Markdown"
        end

      def to_html(xmldoctype = true)
        if blank?
          ""
        else
          HoboFields::SanitizeHtml.sanitize(@@markdown_class.new(self).to_html)
        end
      end

    end
  end
end
