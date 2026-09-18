class ApplicationController < ActionController::API
  include Authenticatable

  rescue_from BaseError do |error|
    render json: error, status: error.http_status
  end

  rescue_from ActiveRecord::RecordInvalid do |error|
    render json: { code: "validation_failed", message: error.message, details: error.record.errors.as_json }, status: :unprocessable_entity
  end

  rescue_from ActiveRecord::RecordNotFound do |error|
    render json: { code: "not_found", message: error.message, details: {} }, status: :not_found
  end
end
