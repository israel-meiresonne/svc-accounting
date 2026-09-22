class Transactions::Csv::Format::OutputPath
  include Interactor::Initializer

  DIRECTORY = Rails.root.join("tmp", "transaction_formatting")

  initialize_with :provider

  def run
    FileUtils.mkdir_p(DIRECTORY)
    DIRECTORY.join("#{next_sequence}-formatted-from-#{provider}.csv")
  end

  private

  def next_sequence
    format("%02d", Dir.children(DIRECTORY).count + 1)
  end
end
