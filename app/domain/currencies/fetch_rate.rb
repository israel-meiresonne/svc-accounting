class Currencies::FetchRate
  include Interactor::Initializer

  PROVIDERS = [
    Integrations::Currencylayer::Services::FetchRate,
    Integrations::Freecurrencyapi::Services::FetchRate
  ].freeze

  initialize_with :currency

  def run
    rate = fetch_from_providers
    return if rate.nil?

    CurrencyRate.find_or_initialize_by(left: CurrencyRate::CENTRAL_CURRENCY, right: currency).update!(rate: rate)
  end

  private

  def fetch_from_providers
    PROVIDERS.each do |provider|
      result = try_provider(provider)
      return result if result
    end
    nil
  end

  def try_provider(provider)
    provider.for(currency)
  rescue HttpClient::Errors::RequestError
    nil
  end
end
