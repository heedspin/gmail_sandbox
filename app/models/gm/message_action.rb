# == Schema Information
#
# Table name: gm_message_actions
#
#  id            :integer          not null, primary key
#  user_id       :integer
#  history_id    :string
#  gmail_id      :string
#  internal_date :datetime
#  label_ids     :string
#  snippet       :string
#  actions       :string
#
class Gm::MessageAction < ApplicationRecord
  self.table_name = 'gm_message_actions'
  belongs_to :user
  scope :user_message, -> (user, gmail_id) {
    where(user_id: user.id, gmail_id: gmail_id)
  }
  scope :by_history_id_desc, -> {
    order(history_id: :desc)
  }
  scope :older_than_a_week, -> {
    where ['gm_message_actions.internal_date < ?', Time.now.advance(days: -7)]
  }
end
