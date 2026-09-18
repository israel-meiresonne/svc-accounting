class Integrations::Currencylayer::Configurations::Base
  include Interactor::Initializer

  BASE_URL = "http://apilayer.net"

  initialize_with :currency

  def run
    {
      base_url: BASE_URL,
      method: :get,
      path: "/api/live",
      params: {
        access_key: ENV.fetch("CURRENCYLAYER_API_KEY"),
        source: CurrencyRate::CENTRAL_CURRENCY.upcase,
        currencies: currency.upcase
      }
    }
  end
end
