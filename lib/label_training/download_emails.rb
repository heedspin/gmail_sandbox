# LabelTraining::DownloadEmails.new(User.first).run('1OWL24', limit: 50)
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
          result = @gmail.list_user_threads('me', label_ids: [label.id], max_results: 1, page_token: page_token)
          result.threads.each do |thread|
            buffer = self.download_thread(thread)
            self.save_thread(label, thread, buffer)
            download_count += 1
            if (limit and (download_count >= limit))
              log "Reached limit of #{limit}"
              return true
            end
          end
          page_token = result.next_page_token
        end while (result.threads.size > 0)
      end
    end
    true
  end

  class MessageBuffer
    attr_accessor :headers
    attr_accessor :label_ids
    attr_accessor :body_parts
    def initialize
      @body_parts = []
    end
    def add_body_part(body_part)
      @body_parts.push body_part
    end
    def label_names(labels_cache)
      @label_ids.map { |id| labels_cache[id].try(:name) || id }
    end
  end
  class ThreadBuffer
    attr_accessor :message_buffers
    def initialize(thread)
      @thread = thread
      @message_buffers = []
    end
    def add_message(message_buffer)
      @message_buffers.push(message_buffer)
    end
    def received_datecode
      if internal_date = @thread.messages.first.try(:internal_date)
        received_time = Time.at(internal_date / 1000.0)
        received_time.strftime('%y%m%d')
      else
        '000000'
      end
    end
    def subject
      header = @message_buffers.first.headers.find { |h| h.name == 'Subject' }
      header.value
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
    thread_buffer = ThreadBuffer.new(result)
    result.messages.each do |message|
      message_buffer = MessageBuffer.new
      message_buffer.label_ids = message.label_ids
      message_buffer.headers = message.payload.headers.select { |h| ['From', 'Date', 'Subject', 'To', 'Cc'].include?(h.name) }
      # "Headers=" + headers.map { |h| "#{h.name} #{h.value}" }.join("\n")
      if message.payload.parts.nil?
        log "No payload parts for message #{message.id}"
      else
        message.payload.parts.map do |part|
          if part.mime_type == 'text/html'
            message_buffer.add_body_part(part.body.data)
          end
        end
      end
      thread_buffer.add_message(message_buffer)
    end
    thread_buffer
  end

  def utf8_encode(text)
    if text.encoding == Encoding::UTF_8
      text
    else
      text.force_encoding('UTF-8')
      # text.encode('UTF-8', 'ASCII-8BIT', invalid: :replace, undef: :replace)
    end
  end

  def save_thread(label, thread, thread_buffer)
    destination_folder = self.ensure_subfolder(thread_buffer.received_datecode)
    destination_filename = "#{thread.id} #{thread_buffer.subject}".parameterize
    destination_file_path = File.join(destination_folder, destination_filename) + '.html'
    File.open(destination_file_path, 'w') do |file|
      file.puts '========================================================'
      thread_buffer.message_buffers.each do |message_buffer|
        message_buffer.label_names(@labels_cache).each do |label|
          file.puts "Label: #{utf8_encode label}"
        end
        message_buffer.headers.each do |header|
          file.puts("#{header.name}: #{utf8_encode header.value}")
        end
        message_buffer.body_parts.each do |part|
          log "Body part: #{part}"
          file.puts(utf8_encode part)
          file.puts '-----------------------------------------------------'
        end
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