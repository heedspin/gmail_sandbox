require 'plutolib/logger_utils'
require 'ostruct'

# LabelTraining::SummarizeThread.new.summarize_thread(sub_path: '241126/1936a8af98052049-loan-proposal-205-speight-st-havelock-nc-28532.html', assistant_id: 'asst_PseTO98UE3ZbP8OCJxffVYma')
# LabelTraining::SummarizeThread.new.summarize_thread(sub_path: '241127/1936e3f0e6ddc2cd-205-speight-at-havelock.html', assistant_id: 'asst_PseTO98UE3ZbP8OCJxffVYma')
class LabelTraining::SummarizeThread
  include Plutolib::LoggerUtils

  # Usage: CountyFinder.new(loan).delay.run!
  def summarize_thread(sub_path:, assistant_id:)
    path_to_thread = File.join('/var/www/gmail_sandbox/storage/emails', sub_path)
    client = OpenAI::Client.new
    message_file = OpenStruct.new client.files.upload(parameters: { file: path_to_thread, purpose: "assistants" })
    prompt = "Please summarize this email thread."
    thread = OpenStruct.new client.threads.create
    message = client.messages.create(
      thread_id: thread.id,
      parameters: {
        role: 'user',
        content: prompt,
        attachments: [
          { file_id: message_file.id, tools: [ { type: 'file_search' } ] }
        ]
      }
    )
    log "Running prompt: #{prompt} with file #{path_to_thread}"
    run = OpenStruct.new client.runs.create(thread_id: thread.id,  parameters: { assistant_id: assistant_id })
    begin
      response = client.runs.retrieve(id: run.id, thread_id: thread.id)
      status = response['status']
      continue = ['queued', 'in_progress', 'cancelling'].include?(status)
      log status
      sleep 1 if continue
    end while continue
    messages = client.messages.list(thread_id: thread.id, parameters: { order: 'asc' })
    messages['data'].each do |message|
      message['content'].each do |content|
        log content.dig('text', 'value')
      end
    end
    client.files.delete(id: message_file.id)
    client.threads.delete(id: thread.id)
    true
  rescue Faraday::Error => e
    log_error e.response.dig(:body, 'error', 'message'), e
    false
  end

  # LabelTraining::SummarizeThread.new.create_assistant
  def create_assistant
    client = OpenAI::Client.new
    assistant = OpenStruct.new client.assistants.create(parameters: {
      model: 'gpt-4o-mini',
      name: 'Email Summarizer',
      instructions: "You read an email and summarize it concisely.",
      tools: [{type: "file_search"}]
    })
    log "Created assistant #{assistant.id}"
    assistant.id
  end

  # LabelTraining::SummarizeThread.new.delete_all_files
  def delete_all_files
    client = OpenAI::Client.new
    files_list = client.files.list
    files_list['data'].each do |file_hash|
      log "Deleting file #{file_hash['filename']} #{file_hash['id']}"
      client.files.delete(id: file_hash['id'])
    end
    true
  end

  # LabelTraining::SummarizeThread.new.delete_all_assistants
  def delete_all_assistants
    client = OpenAI::Client.new
    assistants_list = client.assistants.list
    assistants_list['data'].each do |assistant_hash|
      log "Deleting assistant #{assistant_hash['id']}"
      client.assistants.delete(id: assistant_hash['id'])
    end
    true
  end
end