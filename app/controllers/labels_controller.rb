class LabelsController < ApplicationController
  def index
    @labels = GmailLabels.new(current_user).user_label_names('1OWL24')
  end
end