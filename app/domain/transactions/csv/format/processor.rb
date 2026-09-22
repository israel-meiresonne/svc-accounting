class Transactions::Csv::Format::Processor
  include Interactor::Initializer

  PROCESSORS = {
    "revolut" => Transactions::Csv::Format::FromRevolut
  }.freeze

  initialize_with_keyword_params :provider, :user, :csv_rows

  def run
    raise_unknown_provider unless processor

    processor.for(user: user, csv_rows: csv_rows)
  end

  private

  def processor
    @processor ||= PROCESSORS[provider]
  end

  def raise_unknown_provider
    raise Transactions::Errors::UnknownCsvProviderError.new(details: { provider: provider })
  end
end
