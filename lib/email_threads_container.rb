class EmailThreadsContainer
  include Plutolib::LoggerUtils

  attr_accessor :next_page_token
  attr_accessor :threads

  def initialize(current_user)
    GmailServiceWrapper.create(current_user)
  end

  # log "Labels for #{current_user}: ", GmailLabels.new(current_user).user_label_names('1OWL24')
  def load_threads
    result = nil
    GmailServiceWrapper.use do |gmail|
      # list_user_threads(user_id, include_spam_trash: nil, label_ids: nil, 
      # max_results: nil, page_token: nil, q: nil, 
      # fields: nil, quota_user: nil, user_ip: nil, options: nil) {|result, err| ... } ⇒
      result = gmail.list_user_threads('me', max_results: 10)
    end
    @next_page_token = result.next_page_token
    @threads = result.threads
    true
  end

  def get_thread(thread_id)
    result = nil
    GmailServiceWrapper.use do |gmail|
      # get_user_thread(user_id, id, format: nil, 
      # metadata_headers: nil, fields: nil, quota_user: nil, 
      # user_ip: nil, options: nil) {|result, err| ... } ⇒ Google::Apis::GmailV1::Thread
      result = gmail.get_user_thread('me', thread_id)
    end
    result
  end
end