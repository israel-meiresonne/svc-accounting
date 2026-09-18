class Users::Errors::InvalidCredentialsError < BaseError
  CODE = "invalid_credentials"
  HTTP_STATUS = :unauthorized
  DEFAULT_MESSAGE = "Email or password is incorrect"
end
