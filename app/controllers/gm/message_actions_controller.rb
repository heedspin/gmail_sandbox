class Gm::MessageActionsController < ApplicationController
  def index
    @message_actions = Gm::MessageAction.by_history_id_desc.limit(50)
  end
end