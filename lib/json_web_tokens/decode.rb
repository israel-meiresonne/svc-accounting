class JsonWebTokens::Decode
  include Interactor::Initializer
  include JsonWebTokens::Configurable

  initialize_with :token

  def run
    JWT.decode(token, config[:secret])[0]["user_code"]
  rescue JWT::DecodeError, JWT::ExpiredSignature
    nil
  end
end
