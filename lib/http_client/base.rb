class HttpClient::Base
  include Interactor::Initializer

  REQUIRED_OPTIONS = %i[base_url method path].freeze

  initialize_with :options

  def run
    validate_options!
    perform_request.body
  end

  private

  def validate_options!
    missing = REQUIRED_OPTIONS - options.keys
    return if missing.empty?

    raise HttpClient::Errors::InvalidParametersError.new(details: { missing: missing })
  end

  def perform_request
    connection.public_send(options[:method], options[:path], options[:body]) do |request|
      apply_options!(request)
    end
  rescue Faraday::Error => e
    raise translate_request_error(e)
  end

  def apply_options!(request)
    request.headers.merge!(options[:headers] || {})
    request.params.merge!(options[:params] || {})
  end

  def translate_request_error(error)
    HttpClient::Errors::RequestError.new(
      "#{options[:method].to_s.upcase} #{options[:base_url]}#{options[:path]} failed",
      details: { status: error.response&.dig(:status), body: error.response&.dig(:body) }
    )
  end

  def connection
    Faraday.new(url: options[:base_url]) do |builder|
      builder.request :retry, max: options.fetch(:retry, 3)
      builder.request :json
      builder.response :json
      builder.response :raise_error
    end
  end
end
