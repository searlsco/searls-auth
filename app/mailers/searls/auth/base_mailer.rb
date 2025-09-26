module Searls
  module Auth
    class BaseMailer < ApplicationMailer
      helper Searls::Auth::ApplicationHelper
      include Searls::Auth::ApplicationHelper

      protected

      def format_to(user)
        name_field = searls_auth_helper.attr_for(user, Searls::Auth.config.user_name_method)
        if name_field.present?
          "#{user.name} <#{user.email}>"
        else
          user.email
        end
      end
    end
  end
end
