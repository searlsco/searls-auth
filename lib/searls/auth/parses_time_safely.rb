require "active_support/time"

module Searls
  module Auth
    class ParsesTimeSafely
      def parse(input)
        return nil if input.nil?

        case input
        when String
          parse_string(input)
        when Integer, Float
          Time.at(input).in_time_zone
        else
          if input.respond_to?(:in_time_zone)
            input.in_time_zone
          else
            parse_string(input.to_s)
          end
        end
      rescue ArgumentError, TypeError, NoMethodError
        nil
      end

      private

      def parse_string(s)
        if !(stripped = s.strip).empty?
          Time.zone.parse(stripped)
        end
      end
    end
  end
end
