class JsonWebTokens::Decode
  include Interactor::Initializer

  initialize_with :token

  def run
    decoded_payload.first.fetch("user_code")
  rescue JWT::DecodeError, JWT::ExpiredSignature
    nil
  end

  private

  def decoded_payload
    JWT.decode(token, secret)
  end

  def secret
    JsonWebTokens::Configurations::Base.run.fetch(:secret)
  end
end
