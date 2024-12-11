require 'nokogiri'

class Gm::ThreadParser
  include Plutolib::LoggerUtils
  def self.from_file(sub_path)
    path = Rails.root.join(sub_path)
    thread = Marshal.load(File.open(path).read)
    Gm::ThreadParser.new(gmail_thread: thread)
  end

  attr_accessor :gmail_thread

  def initialize(gmail_thread: nil, gmail_thread_id: nil)
    if gmail_thread
      @gmail_thread = gmail_thread
    elsif gmail_thread_id
      Gm::Service.use do |gmail|
        @gmail_thread = gmail.get_user_thread('me', gmail_thread_id)
      end
    end
  end

  def messages
    if @messages.nil?
      @messages = []
      self.each_message { |m| @messages.push(m) }
    end
    @messages
  end

  def each_message(&block)
    @gmail_thread.messages.each do |gmail_message| 
      block.yield(Gm::Message.new(gmail_message))
    end
  end

  def received_datecode
    if internal_date = self.messages.first.try(:internal_date)
      received_time = Time.at(internal_date / 1000.0)
      received_time.strftime('%y%m%d')
    else
      '000000'
    end
  end
  def subject
    self.messages.first.try(:subject)
  end

  # Gm::ThreadParser.new.debug_thread(User.first, '1932b8cce68fa8b0')
  def debug_thread(user, thread_id)
    Gm::Service.ensure(user)
    log "Debugging thread #{thread_id}"
    result = nil
    Gm::Service.use do |gmail|
      result = gmail.get_user_thread('me', thread_id)
      debugger
      true
    end
  end

  def marshal_thread(user, thread_id, sub_path)
    Gm::Service.ensure(user)
    log "Marshalling thread #{thread_id}"
    thread = nil
    Gm::Service.use do |gmail|
      thread = gmail.get_user_thread('me', thread_id)
    end
    destination_file_path = Rails.root.join(sub_path)
    File.open(destination_file_path, 'wb') do |file|
      Marshal.dump(thread, file)
    end
    log "Marshalled thread to #{destination_file_path}"
    true
  end

end