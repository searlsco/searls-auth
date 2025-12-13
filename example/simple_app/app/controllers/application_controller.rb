class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  protected

  def current_user
    return if session[:user_id].blank?

    @current_user ||= User.find_by(id: session[:user_id])
  end

  def require_user
    if current_user.blank?
      redirect_to searls_auth.login_url({
        redirect_path: request.original_fullpath,
        redirect_host: request.host
      }.compact_blank), allow_other_host: true
    end
  end
end
