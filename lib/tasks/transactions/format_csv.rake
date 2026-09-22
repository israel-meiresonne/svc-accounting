namespace :transactions do
  namespace :csv do
    desc "Format a provider's CSV export into the CSV shape the app's transaction importer accepts"
    task :format, %i[user_code provider file_path] => :environment do |_task, args|
      user = User.find_by!(code: args.user_code)
      rows = CSV.read(args.file_path, headers: true)

      formatted_rows = Transactions::Csv::Format::Processor.for(
        provider: args.provider.to_s.downcase,
        user: user,
        csv_rows: rows
      )

      output_path = Transactions::Csv::Format::OutputPath.for(args.provider.to_s.downcase)
      CSV.open(output_path, "w") do |csv|
        csv << Transactions::Csv::Format::OUTPUT_COLUMNS
        formatted_rows.each { |row| csv << row.values_at(*Transactions::Csv::Format::OUTPUT_COLUMNS) }
      end

      puts "Wrote #{formatted_rows.size} row(s) to #{output_path}"
    end
  end
end
