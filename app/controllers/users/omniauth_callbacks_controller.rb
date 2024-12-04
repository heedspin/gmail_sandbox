# app/controllers/users/omniauth_callbacks_controller.rb:

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  include Plutolib::LoggerUtils

  # https://<hostname>/users/auth/google_oauth2/callback
  def google_oauth2
    auth = request.env['omniauth.auth']
    origin = request.env['omniauth.origin']
    # render json: { auth: auth, origin: origin }
    log "Authorization: ", auth

    @user = User.from_omniauth(auth)

    if @user.persisted?
      flash[:notice] = I18n.t 'devise.omniauth_callbacks.success', kind: 'Google'
      sign_in_and_redirect @user, event: :authentication
    else
      # Useful for debugging login failures. Uncomment for development.
      session['devise.google_data'] = auth.except('extra') # Removing extra as it can overflow some session stores
      redirect_to new_user_registration_url, alert: @user.errors.full_messages.join("\n")
    end
  end

  def failure
    flash[:error] = 'There was an error while trying to authenticate you...'
    redirect_to new_user_session_path
  end
end