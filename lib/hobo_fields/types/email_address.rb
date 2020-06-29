# frozen_string_literal: true

require 'active_support/core_ext/string/output_safety'

module HoboFields
  module Types
    class EmailAddress < String

      COLUMN_TYPE = :string

      MAILBOX           = " [a-z0-9#{ Regexp.escape "!#~%&'=./$*+-?^_`{}|" }]+ "
      SUB_DOMAIN        = %q< [-a-z0-9]+ >
      TOP_LEVEL_DOMAIN  = %q< [a-z]{2,}  >
      DOMAIN            = "(?:#{SUB_DOMAIN}\\.)+ #{TOP_LEVEL_DOMAIN}"
      ADDRESS_REGEXP    = /\A ( #{MAILBOX} ) @ ( #{DOMAIN} ) \z/ix

      def validate
        I18n.t("errors.messages.invalid") unless valid? || blank?
      end

      def valid?
        self.match?(EmailAddress::ADDRESS_REGEXP)
      end

      def to_html(xmldoctype = true)
        ERB::Util.html_escape(self).sub('@', " at ").gsub('.', ' dot ').html_safe
      end

      HoboFields.register_type(:email_address, self)

    end
  end
end

