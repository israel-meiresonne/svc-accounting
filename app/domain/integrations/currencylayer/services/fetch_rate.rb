class Integrations::Currencylayer::Services::FetchRate
  include Interactor::Initializer

  initialize_with :currency

  def run
    response = HttpClient::Base.for(options)
    extract_rate(response)
  end

  private

  def options
    Integrations::Currencylayer::Configurations::Base.for(currency)
  end

  def extract_rate(response)
    BigDecimal(response.dig("quotes", "#{CurrencyRate::CENTRAL_CURRENCY.upcase}#{currency.upcase}").to_s)
  end
end
