class HttpClient::Errors::RequestError < BaseError
  CODE = "http_client_request_error"
  HTTP_STATUS = :bad_gateway
end
