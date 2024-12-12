class CreateGmMessageActions < ActiveRecord::Migration[7.2]
  def change
    create_table :gm_message_actions do |t|
      t.integer :user_id
      t.string :history_id
      t.string :gmail_id
      t.datetime :internal_date
      t.string :label_ids
      t.string :snippet
      t.string :actions
    end
    add_index :gm_message_actions, :gmail_id, unique: true
    add_index :gm_message_actions, :internal_date
  end
end
