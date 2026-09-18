class BaseError < StandardError
  attr_reader :code, :details, :http_status

  def initialize(message = self.class::DEFAULT_MESSAGE, details: {})
    @code = self.class::CODE
    @http_status = self.class::HTTP_STATUS
    @details = details
    super(message)
  end

  def as_json(*)
    { code: code, message: message, details: details }
  end
end
