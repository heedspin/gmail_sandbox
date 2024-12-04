class GmailLabels
  include WithGoogleApi
  include Plutolib::LoggerUtils

  def initialize(current_user)
    @current_user = current_user
  end

  def user_label_names(that_start_with)
    label_names = user_labels(that_start_with).map(&:name)
  end

  def user_labels(that_start_with)
    result = nil
    with_google_api(@current_user) do
      service = Google::Apis::GmailV1::GmailService.new
      service.authorization = @current_user.oauth_access_token
      result = service.list_user_labels('me')
    end
    # result.labels => [ Google::Apis::GmailV1::Label... ]
    # Label: <id, color, label_list_visibility, message_list_visibility, name, type: (system,user)>
    result.labels.select { |l| (l.type == 'user') && (l.name.starts_with?(that_start_with)) }
  end  
end