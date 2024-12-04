# == Schema Information
#
# Table name: users
#
#  id                        :integer          not null, primary key
#  first_name                :string
#  last_name                 :string
#  image_url                 :string
#  status_id                 :integer
#  email                     :string           default(""), not null
#  encrypted_password        :string           default(""), not null
#  reset_password_token      :string
#  reset_password_sent_at    :datetime
#  remember_created_at       :datetime
#  sign_in_count             :integer          default(0), not null
#  current_sign_in_at        :datetime
#  last_sign_in_at           :datetime
#  current_sign_in_ip        :string
#  last_sign_in_ip           :string
#  oauth_provider_account_id :string
#  oauth_access_token        :string
#  oauth_refresh_token       :string
#  oauth_expires_at          :datetime
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
class User < ApplicationRecord
  include Plutolib::LoggerUtils
  include GoogleUser
  include WithGoogleApi
  devise :trackable, :database_authenticatable, :registerable, :omniauthable, omniauth_providers: %i[google_oauth2]

  def full_name
    [self.first_name, self.last_name].join(' ')
  end

  def to_s
    "#{self.full_name} <#{self.email}>"
  end

  def self.from_omniauth(auth)
    info = auth.info
    user = User.where(email: info['email']).first || User.new
    user.attributes = {
      first_name: info['first_name'],
      last_name: info['last_name'],
      email: info['email'],
      password: Devise.friendly_token[0,20],
      image_url: info['image'],
      oauth_provider_account_id: auth.uid,
      oauth_access_token: auth.credentials.token,
      oauth_expires_at: Time.at(auth.credentials.expires_at).to_datetime,
      oauth_refresh_token: auth.credentials.refresh_token,
    }
    user.save!
    user
  end
end
