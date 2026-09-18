class Accounts::Api::V1::AccountsController < ApplicationController
  def index
    summary = Accounts::SumAll.for(accounts: current_user.accounts.active, currency: current_user.currency)
    render json: { accounts: current_user.accounts.active.map { |account| AccountSerializer.new(account) }, summary: summary }, status: :ok
  end

  def create
    account = Accounts::Create.for(**account_params)
    render json: { account: AccountSerializer.new(account) }, status: :created
  end

  def update
    account = Accounts::Update.for(account: current_account, attributes: update_params)
    render json: { account: AccountSerializer.new(account) }, status: :ok
  end

  def destroy
    Accounts::Delete.for(current_account)
    head :no_content
  end

  private

  def current_account
    current_user.accounts.active.find_by!(code: params[:code])
  end

  def account_params
    {
      user: current_user,
      name: params[:name],
      currency: params[:currency],
      initial_balance: params[:initial_balance],
      current_balance: params[:current_balance]
    }
  end

  def update_params
    params.permit(:name, :currency).to_h.symbolize_keys
  end
end
