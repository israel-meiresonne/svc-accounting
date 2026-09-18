require "rails_helper"

RSpec.describe Users::Authenticate, type: :interactor do
  subject { described_class.for(**params) }

  let(:params) { { email: "jane@example.com", password: "password123" } }
  let!(:user) { create(:user, email: "jane@example.com", password: "password123", password_confirmation: "password123") }

  it "returns the authenticated user" do
    expect(subject).to eq(user)
  end

  context "when the email is unknown" do
    let(:params) { { email: "unknown@example.com", password: "password123" } }

    it "raises Users::Errors::InvalidCredentialsError with the generic message" do
      expect { subject }.to raise_error(Users::Errors::InvalidCredentialsError, "Email or password is incorrect")
    end
  end

  context "when the password is wrong" do
    let(:params) { { email: "jane@example.com", password: "wrongpassword" } }

    it "raises Users::Errors::InvalidCredentialsError with the generic message" do
      expect { subject }.to raise_error(Users::Errors::InvalidCredentialsError, "Email or password is incorrect")
    end
  end

  context "when the matching record is not a user type" do
    let!(:user) { create(:contact, email: "jane@example.com") }

    it "raises Users::Errors::InvalidCredentialsError" do
      expect { subject }.to raise_error(Users::Errors::InvalidCredentialsError)
    end
  end
end
