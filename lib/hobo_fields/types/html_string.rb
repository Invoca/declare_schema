module HoboFields
  module Types
    class HtmlString < RawHtmlString
      HoboFields.register_type(:html, self)
    end
  end
end
