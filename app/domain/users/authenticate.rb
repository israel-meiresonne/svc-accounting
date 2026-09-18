class Users::Authenticate
  include Interactor::Initializer

  initialize_with_keyword_params :email, :password

  def run
    raise Users::Errors::InvalidCredentialsError unless user&.authenticate(password)

    user
  end

  private

  def user
    @user ||= User.find_by(email: email, type: "user")
  end
end
