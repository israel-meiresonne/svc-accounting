module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_request!
  end

  private

  attr_reader :current_user

  def authenticate_request!
    @current_user = decoded_user_code && User.find_by(code: decoded_user_code)
    render_unauthorized unless current_user
  end

  def decoded_user_code
    bearer_token && JsonWebTokens::Decode.for(bearer_token)
  end

  def bearer_token
    request.headers["Authorization"]&.split("Bearer ")&.last
  end

  def render_unauthorized
    render json: { code: "unauthorized", message: "Missing or invalid token", details: {} }, status: :unauthorized
  end
end
