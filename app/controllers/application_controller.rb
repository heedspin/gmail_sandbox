class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  helper_method :current_user
  before_action :authenticate_user!
  
  # private
  
  # def current_user
  #   @current_user ||= User.find(session[:user_id]) if session[:user_id]
  # end

  # def authenticate_user!
  #   redirect_to '/auth/google_oauth2' unless current_user
  # end
end