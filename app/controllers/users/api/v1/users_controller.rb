class Users::Api::V1::UsersController < ApplicationController
  skip_before_action :authenticate_request!, only: [ :create, :login ]

  def create
    user = Users::Create.for(**user_params)
    token = JsonWebTokens::Encode.for(user.code)
    render json: { token: token, user: UserSerializer.new(user) }, status: :created
  end

  def login
    user = Users::Authenticate.for(email: params[:email], password: params[:password])
    token = JsonWebTokens::Encode.for(user.code)
    render json: { token: token, user: UserSerializer.new(user) }, status: :ok
  end

  def me
    render json: { user: UserSerializer.new(current_user) }, status: :ok
  end

  def update_me
    user = Users::Update.for(current_user, currency: params[:currency])
    render json: { user: UserSerializer.new(user) }, status: :ok
  end

  private

  def user_params
    params.permit(:first_name, :last_name, :email, :password, :password_confirmation, :currency).to_h.symbolize_keys
  end
end
