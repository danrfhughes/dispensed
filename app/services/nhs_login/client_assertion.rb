module NhsLogin
  # Builds a signed JWT client assertion for NHS Login's private_key_jwt
  # token endpoint authentication.
  #
  # NHS Login requires RS512-signed JWTs at the token endpoint instead of
  # a client_secret. The JWT asserts this app's identity using a registered
  # RSA key pair.
  #
  # See: https://nhsconnect.github.io/nhslogin/oidc-login-flow/
  class ClientAssertion
    ALGORITHM = "RS512"
    LIFETIME = 300 # 5 minutes

    def initialize(token_endpoint:, client_id: nil, private_key: nil)
      @token_endpoint = token_endpoint
      @client_id = client_id || credentials[:client_id]
      @private_key = private_key || OpenSSL::PKey::RSA.new(credentials[:private_key])
    end

    def to_jwt
      JWT.encode(claims, @private_key, ALGORITHM)
    end

    def claims
      now = Time.now.to_i
      {
        iss: @client_id,
        sub: @client_id,
        aud: @token_endpoint,
        jti: SecureRandom.uuid,
        iat: now,
        exp: now + LIFETIME
      }
    end

    private

    def credentials
      Rails.application.credentials.nhs_login || {}
    end
  end
end
