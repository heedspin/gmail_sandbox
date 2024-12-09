# LabelTraining::DownloadEmails.new(User.first).run('1OWL24', limit: 100)
class LabelTraining::DownloadEmails
  include Plutolib::LoggerUtils
  include WithGoogleApi
  def initialize(user)
    log_to_stdout
    @user = user
    @gmail = Google::Apis::GmailV1::GmailService.new
    @gmail.authorization = @user.oauth_access_token
    @labels_cache = {}
  end

  def run(labels_that_start_with, limit: nil)
    unless @user.ensure_oauth_credentials!
      log "Failed to authorize user"
      return false
    end
    download_count = 0
    labels = GmailLabels.new(@user).user_labels(labels_that_start_with)
    log "Got #{labels.size} labels for #{@user}"
    labels.each do |label|
      @labels_cache[label.id] = label
    end
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
        begin
          result = @gmail.list_user_threads('me', label_ids: [label.id], max_results: 10, page_token: page_token)
          result.threads.each do |thread_snippet|
            log "Downloading thread #{thread_snippet.id}"
            gmail_thread = @gmail.get_user_thread('me', thread_snippet.id)
            thread_parser = GmailThreadParser.new(gmail_thread)
            self.save_thread(label, thread_parser)
            download_count += 1
            if (limit and (download_count >= limit))
              log "Reached limit of #{limit}"
              return true
            end
          end
          page_token = result.next_page_token
        end while page_token
      end
    end
    true
  end

  def utf8_encode(text)
    if text.encoding == Encoding::UTF_8
      text
    else
      text.force_encoding('UTF-8')
      # text.encode('UTF-8', 'ASCII-8BIT', invalid: :replace, undef: :replace)
    end
  end

  def save_thread(label, thread_parser)
    destination_folder = self.ensure_subfolder(label.name.parameterize)
    destination_filename = "#{thread_parser.gmail_thread.id} #{thread_parser.subject}".parameterize
    destination_file_path = File.join(destination_folder, destination_filename) + '.html'
    File.open(destination_file_path, 'w') do |file|
      file.puts '========================================================'
      thread_parser.messages.each do |message|
        # message_buffer.label_names(@labels_cache).each do |label_name|
        #   file.puts "Label: #{utf8_encode label_name}"
        # end
        file.puts("<div class=\"header\">")
        file.puts("<span>Gmail Thread ID</span><span>#{thread_parser.gmail_thread.id}</span>")
        message.headers.each do |header|
          file.puts("<span>#{header.name}:</span> <span>#{utf8_encode header.value}</span>")
        end
        file.puts("</div>")
        file.puts(utf8_encode message.content || 'empty message, wut...')
      end
    end
    log "Wrote #{destination_file_path}"
    true
  end

  def ensure_subfolder(*parts)
    path = Rails.root.join('storage', 'emails', *parts)
    if !Dir.exist?(path)
      FileUtils.mkdir_p(path)
    end
    path
  end
end