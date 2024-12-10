require 'plutolib/logger_utils'
require 'ostruct'

# LabelTraining::IdentifyLoanNumber.new.run(sub_path: '1owl24-slo-826-s-5th-st-smithfield-nc-27577/1932b8cce68fa8b0-re-slo-broker.html', assistant_id: 'asst_sF4Xf2tF3mQdMVpXCRaub3hZ', loans_id: 'file-R52ANiCe5YJ1VMnKptGhKL')
class LabelTraining::IdentifyLoanNumber
  include Plutolib::LoggerUtils

  def initialize
    log_to_stdout
    @client = OpenAI::Client.new
  end

  def run(sub_path:, assistant_id:, loans_id:)
    email = self.upload_file(sub_path)
    prompt = "Please read the attached email and identify the appropriate loan number."
    self.analyze_email(prompt: prompt, assistant_id: assistant_id, loans_id: loans_id, email_id: email.id)
    @client.files.delete(id: email.id)
    true
  end

  # rails r "LabelTraining::IdentifyLoanNumber.new.analyze_email(email_id: 'file-Fritgp1ih1tvXBhs6e5Z1J' assistant_id: 'asst_sF4Xf2tF3mQdMVpXCRaub3hZ', loans_id: 'file-R52ANiCe5YJ1VMnKptGhKL')"
  # rails r "LabelTraining::IdentifyLoanNumber.new.analyze_email(prompt: 'Please analyze the email subject.', assistant_id: 'asst_sF4Xf2tF3mQdMVpXCRaub3hZ', loans_id: 'file-R52ANiCe5YJ1VMnKptGhKL', email_id: 'file-FQLs19snudcXQNSHnb5xWV')"
  def analyze_email(prompt:, assistant_id:, loans_id:, email_id:)
    thread = OpenStruct.new @client.threads.create
    message = @client.messages.create(
      thread_id: thread.id,
      parameters: {
        role: 'user',
        content: prompt,
        attachments: [
          { file_id: email_id, tools: [ { type: 'file_search' } ] },
          { file_id: loans_id, tools: [ { type: 'file_search' } ] }
        ]
      }
    )
    log "Running prompt: #{prompt} with file #{email_id}"
    run = OpenStruct.new @client.runs.create(thread_id: thread.id,  parameters: { assistant_id: assistant_id })
    begin
      response = @client.runs.retrieve(id: run.id, thread_id: thread.id)
      status = response['status']
      continue = ['queued', 'in_progress', 'cancelling'].include?(status)
      log status
      if continue
        sleep 1
      else
        if status != 'completed'
          log response.inspect
        end
      end
    end while continue
    messages = @client.messages.list(thread_id: thread.id, parameters: { order: 'asc' })
    messages['data'].each do |message|
      message['content'].each do |content|
        log content.dig('text', 'value')
      end
    end
    @client.threads.delete(id: thread.id)
    true
  rescue Faraday::Error => e
    log_error e.response.dig(:body, 'error', 'message'), e
    false
  end

  # LabelTraining::IdentifyLoanNumber.new.create_loan_number_identifier_assistant
  def create_loan_number_identifier_assistant
    instructions = <<-TEXT
You are given an email as a text/html attachment and a list of loan records as a json attachment. Read the email and determine which loan the email is regarding. 

Weigh the email subject heavily.  Use the loans attachment to find the loan number using address, borrower name, loan attorney, and the contacts.

If there is no address in the email, use the email sender and recipients to help you find the relevant loan number.

If you are not sure, return 'unknown'.
      TEXT
    assistant = OpenStruct.new @client.assistants.create(parameters: {
      model: 'gpt-4o-mini',
      name: 'Loan Number Identifier',
      instructions: instructions,
      tools: [{type: "file_search"}]
    })
    log "Created assistant #{assistant.id}"
    assistant.id
  end

  def create_email_parser_assistant
    assistant = OpenStruct.new @client.assistants.create(parameters: {
      model: 'gpt-4o-mini-2024-07-18',
      name: 'Loan Number Identifier',
      instructions: "You are given an email as a text/html attachment and a list of loan records as a json attachment. Read the email and determine the email sender, recipients, and subject.",
      tools: [{type: "file_search"}]
    })
    log "Created assistant #{assistant.id}"
    assistant.id
  end
  # LabelTraining::IdentifyLoanNumber.new.upload_loans
  def upload_loans
    path_to_loans = '/var/www/owl-staging/log/loans.json'
    loans = OpenStruct.new @client.files.upload(parameters: { file: path_to_loans, purpose: "assistants" })
    log "Uploaded loans: #{loans.id}"
    true
  end


  # rails r "LabelTraining::IdentifyLoanNumber.new.upload_file('1owl24-thtm-7017-candlewood-dr-fayetteville-nc-28314/19277b49477ad3c5-fwd-fw-message-from-rnp58387933d42d.html')"
  # rails r "LabelTraining::IdentifyLoanNumber.new.upload_file('1owl24-thtm-7017-candlewood-dr-fayetteville-nc-28314/1925f8d16ca62e9e-loan-proposal-7017-candlewood-dr-fayetteville-nc-28314.html')"
  # rails r "LabelTraining::IdentifyLoanNumber.new.upload_file('1owl24-slo-826-s-5th-st-smithfield-nc-27577/1932b8cce68fa8b0-re-slo-broker.html')"
  def upload_file(sub_path)
    path_to_thread = File.join('/var/www/gmail_sandbox/storage/emails', sub_path)
    email = OpenStruct.new @client.files.upload(parameters: { file: path_to_thread, purpose: "assistants" })
    log "Uploaded #{path_to_thread} to file id #{email.id}"
    email
  end

  # LabelTraining::SummarizeThread.new.delete_all_files
  def delete_all_files
    files_list = @client.files.list
    files_list['data'].each do |file_hash|
      log "Deleting file #{file_hash['filename']} #{file_hash['id']}"
      @client.files.delete(id: file_hash['id'])
    end
    true
  end

  # LabelTraining::SummarizeThread.new.delete_all_assistants
  def delete_all_assistants
    assistants_list = @client.assistants.list
    assistants_list['data'].each do |assistant_hash|
      log "Deleting assistant #{assistant_hash['id']}"
      @client.assistants.delete(id: assistant_hash['id'])
    end
    true
  end
end