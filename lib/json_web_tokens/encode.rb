class JsonWebTokens::Encode
  include Interactor::Initializer
  include JsonWebTokens::Configurable

  initialize_with :user_code

  def run
    JWT.encode(payload, config[:secret])
  end

  private

  def payload
    { user_code: user_code, exp: (Time.current + config[:expiration]).to_i }
  end
end
