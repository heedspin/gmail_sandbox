# LabelTraining::DownloadEmails.new(User.first).run('1OWL24')
class LabelTraining::DownloadEmails
  include Plutolib::LoggerUtils
  include WithGoogleApi
  def initialize(user)
    log_to_stdout
    @user = user
    @gmail = Google::Apis::GmailV1::GmailService.new
    @gmail.authorization = @user.oauth_access_token
  end

  def run(labels_that_start_with)
    labels = GmailLabels.new(@user).user_labels(labels_that_start_with)
    log "Got #{labels.size} labels for #{@user}"
    labels = [labels.first]
    labels.each do |label|
      next if label.name == labels_that_start_with # Skip top level
      parts = label.name.split('/')
      if parts.size != 2
        log_error "Skipping unexpected label: #{label.name}"
        next
      end

      result = nil
      with_google_api(@user) do
        #list_user_threads(user_id, include_spam_trash: nil, label_ids: nil, max_results: nil, page_token: nil, q: nil, fields: nil, quota_user: nil, user_ip: nil, options: nil) {|result, err| ... } ⇒ Google::Apis::GmailV1::ListThreadsResponse
        page_token = nil
        # loop do
          result = @gmail.list_user_threads('me', label_ids: [label.id], max_results: 1, page_token: page_token)
          self.download_thread(result.threads.first)
          # result.threads.each do |thread|
          #   self.download_thread(thread)
          # end
          page_token = result.next_page_token
        # while (result.threads > 0)
      end

      # self.ensure_folder(parts)
      # self.store_email()
    end
  end

  def download_thread(thread)
    log "Downloading thread #{thread.id}"
    result = nil
    with_google_api(@user) do
      # get_user_thread(user_id, id, format: nil, 
      # metadata_headers: nil, fields: nil, quota_user: nil, 
      # user_ip: nil, options: nil) {|result, err| ... } ⇒ Google::Apis::GmailV1::Thread
      result = @gmail.get_user_thread('me', thread.id)
    end
    result.messages.each do |message|
      headers = message.payload.headers.select { |h| ['From', 'Date', 'Subject', 'To', 'Cc'].include?(h.name) }
      log "Headers=" + headers.map { |h| "#{h.name} #{h.value}" }.join("\n")
      message.payload.parts.each do |part|
        if part.mime_type == 'text/plain'
          log "Body=" + part.body.data
        end
      end
    end
  end

  def ensure_folder(parts)
    path = Rails.root.join('storage', 'emails', *parts)
    if !Dir.exist?(path)
      FileUtils.mkdir_p(path)
    end
    true
  end
end