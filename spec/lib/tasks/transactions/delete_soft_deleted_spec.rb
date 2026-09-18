require "rails_helper"

RSpec.describe "transactions:delete_soft_deleted", type: :rake do
  subject { Rake::Task["transactions:delete_soft_deleted"].execute }

  it "calls Transactions::DeleteSoftDeletedRecords.run" do
    expect(Transactions::DeleteSoftDeletedRecords).to receive(:run)

    subject
  end
end
