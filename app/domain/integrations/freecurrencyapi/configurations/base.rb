class Integrations::Freecurrencyapi::Configurations::Base
  include Interactor::Initializer

  BASE_URL = "https://api.freecurrencyapi.com"

  initialize_with :currency

  def run
    {
      base_url: BASE_URL,
      method: :get,
      path: "/v1/latest",
      params: {
        apikey: ENV.fetch("FREECURRENCYAPI_API_KEY"),
        base_currency: CurrencyRate::CENTRAL_CURRENCY.upcase,
        currencies: currency.upcase
      }
    }
  end
end
