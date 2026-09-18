class JsonWebTokens::Configurations::Base
  include Interactor::Initializer

  DEFAULT_EXPIRATION = 7.days

  def run
    { secret: Rails.application.credentials.secret_key_base, expiration: DEFAULT_EXPIRATION }
  end
end
