module Searls
  module Auth
    class SanitizesFlashHtml
      def initialize
        require "rails-html-sanitizer"
        @safe_list_sanitizer = Rails::HTML::SafeListSanitizer.new
      end

      def sanitize(html)
        @safe_list_sanitizer.sanitize(
          html,
          tags: %w[a b br code em i li ol p strong u ul],
          attributes: %w[data-turbo-confirm data-turbo-method href rel target title]
        )
      end
    end
  end
end
