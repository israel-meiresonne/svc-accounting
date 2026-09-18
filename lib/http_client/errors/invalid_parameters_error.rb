class HttpClient::Errors::InvalidParametersError < BaseError
  CODE = "http_client_invalid_parameters"
  HTTP_STATUS = :internal_server_error
  DEFAULT_MESSAGE = "Required HTTP client options are missing"
end
