module Searls
  module Auth
    class ResetsSession
      def reset(receiver, except_for:)
        backup = Searls::Auth.config.preserve_session_keys_after_logout.map { |key|
          [key, receiver.session[key]]
        }
        receiver.reset_session
        backup.each { |key, value| receiver.session[key] = value }
      end
    end
  end
end
