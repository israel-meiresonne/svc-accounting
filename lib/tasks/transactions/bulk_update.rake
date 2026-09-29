namespace :transactions do
  desc "Bulk-update transactions from a CSV file (columns match transaction attribute names, identified by `code`)"
  task :bulk_update, %i[file_path] => :environment do |_task, args|
    csv_rows = CSV.read(args.file_path, headers: true)

    Transactions::Bulk::UpdateFromCsv.for(csv_rows: csv_rows)

    puts "Updated #{csv_rows.size} transaction(s)."
  end
end
