class JsonWebTokens::Configurations::Base
  include Interactor::Initializer

  DEFAULT_EXPIRATION = 7.days

  def run
    { secret: secret, expiration: DEFAULT_EXPIRATION }
  end

  private

  def secret
    ENV.fetch('JWT_SECRET_KEY')
  end
end
