require "rails_helper"

RSpec.describe Users::Create, type: :interactor do
  subject { described_class.for(**params) }

  let(:params) do
    {
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.com",
      password: "password123",
      password_confirmation: "password123",
      currency: "usd"
    }
  end

  it "creates a user of type user" do
    expect(subject.type).to eq("user")
  end

  it "persists the user" do
    expect { subject }.to change(User, :count).by(1)
  end

  it "returns the created user" do
    expect(subject).to be_a(User)
  end

  context "when the email is already taken" do
    let!(:existing_user) { create(:user, email: "jane@example.com") }

    it "raises ActiveRecord::RecordInvalid" do
      expect { subject }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  context "when the password confirmation does not match" do
    let(:params) do
      {
        first_name: "Jane",
        last_name: "Doe",
        email: "jane@example.com",
        password: "password123",
        password_confirmation: "somethingelse",
        currency: "usd"
      }
    end

    it "raises ActiveRecord::RecordInvalid" do
      expect { subject }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
