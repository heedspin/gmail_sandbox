AppConfig.load_config(Rails.root.join('config/openai_config.yaml'))
OpenAI.configure do |config|
  config.access_token = AppConfig.openai_key
  config.log_errors = true
end
