class Transactions::Api::V1::TransactionsController < ApplicationController
  IMPORT_ROW_PARAMS = %i[
    account_code occurred_at amount currency payment_method category description
    counterparty_type counterparty_first_name counterparty_last_name counterparty_company_name
    counterparty_email counterparty_code dedup_hash resolution
  ].freeze
  UPDATABLE_PARAMS = %i[amount category description payment_method occurred_at].freeze
  COUNTERPARTY_OPTION_PARAMS = %i[type first_name last_name company_name email].freeze

  def create
    transaction = Transactions::Create.for(**create_attributes)
    render json: { transaction: TransactionSerializer.new(transaction) }, status: :created
  end

  def update
    transaction = Transactions::Update.for(transaction: owned_transaction, attributes: update_attributes)
    render json: { transaction: TransactionSerializer.new(transaction) }, status: :ok
  end

  def stats
    render json: Transactions::CalculateStats.for(account: owned_account, from: params[:from], to: params[:to]), status: :ok
  end

  def import_preview
    rows = Transactions::Csv::Import::Preview.for(user_account: current_user.accounts.active, rows: import_rows)
    render json: { rows: rows }, status: :ok
  end

  def import_commit
    result = Transactions::Csv::Import::Commit.for(user_account: current_user.accounts.active, rows: import_rows)
    render json: result, status: :ok
  end

  def index
    transactions = Transactions::Search.for(
      user: current_user,
      from: params[:from]&.to_date,
      to: params[:to]&.to_date,
      filters: params.fetch(:filter, {}),
      sort: params[:sort],
      order: params[:order],
      page: params[:page],
      per_page: params.fetch(:per_page, 50),
    )
    render json: { data: transactions.map { |t| TransactionSerializer.new(t) }, meta: pagination_meta(transactions) }
  end

  def bulk_update
    count = Transactions::Bulk::Update.for(user: current_user, transaction_codes: params[:transaction_codes], attributes: bulk_update_attributes)
    render json: { updated_count: count }
  end

  def bulk_delete
    count = Transactions::Bulk::Delete.for(user: current_user, transaction_codes: params[:transaction_codes])
    render json: { deleted_count: count }
  end

  def bulk_move
    count = Transactions::Bulk::Move.for(
      user: current_user,
      transaction_codes: params[:transaction_codes],
      destination_account_code: params[:destination_account_code],
    )
    render json: { moved_count: count }
  end

  def bulk_export_csv
    csv = Transactions::Bulk::ExportCsv.for(user: current_user, transaction_codes: params[:transaction_codes])
    send_data csv, type: "text/csv", filename: "transactions.csv", disposition: "attachment"
  end

  def bulk_generate_report
    pdf = Transactions::Pdf::Report::Build.for(
      user: current_user,
      transaction_codes: params[:transaction_codes],
      title: params[:title],
      description: params[:description],
      reporting_currency: params[:reporting_currency],
    )
    send_data pdf, type: "application/pdf", filename: "report.pdf", disposition: "attachment"
  end

  private

  def create_attributes
    {
      account: owned_account,
      amount: params[:amount],
      category: params[:category],
      description: params[:description],
      payment_method: params[:payment_method],
      occurred_at: params[:occurred_at],
      counterparty_id: counterparty_id,
      counterparty_options: counterparty_options
    }
  end

  def update_attributes
    params.permit(*UPDATABLE_PARAMS).to_h.symbolize_keys.merge(counterparty_attributes)
  end

  def counterparty_attributes
    return { counterparty_id: counterparty_id } if params[:counterparty_code].present?
    return { counterparty_options: counterparty_options } if params[:counterparty_options].present?

    {}
  end

  def owned_account
    @owned_account ||= current_user.accounts.active.find_by!(code: params[:account_code])
  end

  def owned_transaction
    owned_account.transactions.active.find_by!(code: params[:code])
  end

  def counterparty_id
    return if params[:counterparty_code].blank?

    User.find_by!(code: params[:counterparty_code]).id
  end

  def counterparty_options
    params[:counterparty_options]&.permit(*COUNTERPARTY_OPTION_PARAMS)&.to_h&.symbolize_keys
  end

  def import_rows
    params.require(:rows).map { |row| row.permit(*IMPORT_ROW_PARAMS).to_h.symbolize_keys }
  end

  def bulk_update_attributes
    params.fetch(:attributes, {}).to_unsafe_h
  end

  def pagination_meta(transactions)
    {
      page: transactions.current_page,
      per_page: transactions.limit_value,
      total_count: transactions.total_count,
      total_pages: transactions.total_pages
    }
  end
end
