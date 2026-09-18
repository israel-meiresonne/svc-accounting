namespace :currencies do
  desc "Fetch and store the latest exchange rate for every currency in active use"
  task fetch_rates: :environment do
    Account.active.distinct.pluck(:currency).excluding(CurrencyRate::CENTRAL_CURRENCY).each do |currency|
      Currencies::FetchRate.for(currency)
    end
  end
end
