class UserSerializer
  def initialize(user)
    @user = user
  end

  def as_json(*)
    {
      code: user.code,
      first_name: user.first_name,
      last_name: user.last_name,
      email: user.email,
      currency: user.currency
    }
  end

  private

  attr_reader :user
end
