class Users::ResolveCounterparty
  include Interactor::Initializer

  initialize_with :options

  def run
    existing_user || new_user
  end

  private

  def existing_user
    User.find_by(email: options[:email]) if options[:email].present?
  end

  def new_user
    User.create!(
      type: options[:type],
      first_name: options[:first_name],
      last_name: options[:last_name],
      company_name: options[:company_name],
      email: options[:email],
    )
  end
end
