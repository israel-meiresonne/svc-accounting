class Users::Create
  include Interactor::Initializer

  initialize_with_keyword_params :first_name, :last_name, :email, :password, :password_confirmation, :currency

  def run
    user.save!
    user
  end

  private

  def user
    @user ||= User.new(
      type: "user",
      first_name: first_name,
      last_name: last_name,
      email: email,
      password: password,
      password_confirmation: password_confirmation,
      currency: currency,
    )
  end
end
