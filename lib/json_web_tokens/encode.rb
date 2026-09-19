class JsonWebTokens::Encode
  include Interactor::Initializer

  initialize_with :user_code

  def run
    JWT.encode(payload, secret)
  end

  private

  def payload
    { user_code: user_code, exp: (Time.current + expiration).to_i }
  end

  def secret
    config.fetch(:secret)
  end

  def expiration
    config.fetch(:expiration)
  end

  def config
    JsonWebTokens::Configurations::Base.run
  end
end
