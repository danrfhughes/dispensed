require "rails_helper"

RSpec.describe NhsLogin::ClientAssertion, type: :model do
  let(:private_key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:client_id) { "dispensed-test-client" }
  let(:token_endpoint) { "https://oidc.mock.signin.nhs.uk/token" }

  subject(:assertion) do
    described_class.new(
      token_endpoint: token_endpoint,
      client_id: client_id,
      private_key: private_key
    )
  end

  describe "#claims" do
    it "includes required JWT claims" do
      claims = assertion.claims
      expect(claims[:iss]).to eq(client_id)
      expect(claims[:sub]).to eq(client_id)
      expect(claims[:aud]).to eq(token_endpoint)
      expect(claims[:jti]).to be_present
      expect(claims[:iat]).to be_a(Integer)
      expect(claims[:exp]).to be_a(Integer)
    end

    it "sets expiry 5 minutes in the future" do
      claims = assertion.claims
      expect(claims[:exp] - claims[:iat]).to eq(300)
    end

    it "generates unique jti per call" do
      jti1 = assertion.claims[:jti]
      jti2 = assertion.claims[:jti]
      expect(jti1).not_to eq(jti2)
    end
  end

  describe "#to_jwt" do
    it "returns a valid RS512-signed JWT" do
      jwt = assertion.to_jwt
      decoded = JWT.decode(jwt, private_key.public_key, true, algorithm: "RS512")
      expect(decoded.first["iss"]).to eq(client_id)
      expect(decoded.first["aud"]).to eq(token_endpoint)
    end

    it "cannot be verified with a different key" do
      jwt = assertion.to_jwt
      wrong_key = OpenSSL::PKey::RSA.generate(2048)
      expect {
        JWT.decode(jwt, wrong_key.public_key, true, algorithm: "RS512")
      }.to raise_error(JWT::VerificationError)
    end

    it "uses RS512 algorithm" do
      jwt = assertion.to_jwt
      # Decode without verification to inspect header
      header = JWT.decode(jwt, nil, false).last
      expect(header["alg"]).to eq("RS512")
    end
  end
end
