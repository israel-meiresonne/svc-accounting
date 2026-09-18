class Users::Update
  include Interactor::Initializer

  initialize_with :user, :attributes

  def run
    user.update!(attributes)
    user
  end
end
