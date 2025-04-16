module Searls
  module Auth
    class RegistrationsController < BaseController
      def show
        render searls_auth_config.register_view, layout: searls_auth_config.layout
      end

      def create
        result = CreatesUser.new.call(params)

        if result.success?
          attach_short_code_to_session!(result.user)

          redirect_params = {
            redirect_path: searls_auth_config.resolve(
              :redirect_path_after_register,
              result.user, params, request, main_app
            )
          }

          EmailsLink.new.email(
            user: result.user,
            short_code: session[:email_auth_short_code],
            **redirect_params
          )
          flash[:notice] = "Verification email sent to #{params[:email]}"
          redirect_to searls_auth.verify_path(**redirect_params)
        else
          flash.now[:error] = result.error_messages
          render searls_auth_config.register_view, layout: searls_auth_config.layout, status: :unprocessable_entity
        end
      end
    end
  end
end
