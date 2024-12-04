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
require "test_helper"

class UserTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
