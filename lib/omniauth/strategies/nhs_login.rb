# frozen_string_literal: true

require "omniauth/strategies/openid_connect"

module OmniAuth
  module Strategies
    # Custom OmniAuth strategy for NHS Login.
    #
    # Extends the standard OpenID Connect strategy to inject an RS512-signed
    # client_assertion at the token endpoint (NHS Login's required
    # private_key_jwt auth method).
    #
    # rack-oauth2's built-in :jwt_bearer auto-generates RS256 assertions,
    # but NHS Login requires RS512. This strategy builds the assertion via
    # NhsLogin::ClientAssertion and passes it explicitly.
    class NhsLogin < OpenIDConnect
      option :name, "nhslogin"

      # Override access_token to inject our RS512 client_assertion
      def access_token
        return @access_token if @access_token

        assertion = ::NhsLogin::ClientAssertion.new(
          token_endpoint: client.token_endpoint
        )

        token_request_params = {
          scope: (options.scope if options.send_scope_to_token_endpoint),
          client_auth_method: :jwt_bearer,
          client_assertion: assertion.to_jwt
        }

        if options.pkce
          token_request_params[:code_verifier] =
            params["code_verifier"] || session.delete("omniauth.pkce.verifier")
        end

        @access_token = client.access_token!(token_request_params)
        verify_id_token!(@access_token.id_token) if configured_response_type == "code"

        @access_token
      end

      # Extract NHS-specific claims into the auth hash extra info
      extra do
        {
          raw_info: user_info.raw_attributes,
          vot: user_info.raw_attributes[:vot],
          nhs_number: user_info.raw_attributes[:nhs_number]
        }
      end
    end
  end
end
