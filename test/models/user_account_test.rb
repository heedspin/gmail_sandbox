# == Schema Information
#
# Table name: user_accounts
#
#  id                  :integer          not null, primary key
#  user_id             :integer          not null
#  autho_protocol      :string           default("oauth2")
#  provider            :string
#  provider_account_id :string
#  access_token        :string
#  token_type          :string           default("Bearer")
#  scope               :string
#  refresh_token       :string
#  expires_at          :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
require "test_helper"

class UserAccountTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
