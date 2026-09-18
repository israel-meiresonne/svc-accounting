class Transactions::Api::V1::StatisticsController < ApplicationController
  def show
    render json: Transactions::Statistics::Aggregate.for(
      current_user: current_user,
      from: Date.iso8601(params[:from]),
      to: Date.iso8601(params[:to]),
      account_codes: params[:account_codes],
      category: params[:category],
      payment_method: params[:payment_method],
    )
  end
end
