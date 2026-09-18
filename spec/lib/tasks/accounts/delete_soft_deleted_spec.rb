require "rails_helper"

RSpec.describe "accounts:delete_soft_deleted", type: :rake do
  subject { Rake::Task["accounts:delete_soft_deleted"].execute }

  it "calls Accounts::DeleteSoftDeletedRecords.run" do
    expect(Accounts::DeleteSoftDeletedRecords).to receive(:run)

    subject
  end
end
