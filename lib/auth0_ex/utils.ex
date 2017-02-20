defmodule Auth0Ex.Utils do
  @moduledoc """
  Collection module of various utils needed for Auth0Ex
  """
  alias Auth0Ex.TokenState

  def base_url, do: "https://#{domain()}.auth0.com/api/v2/"
  def oauth_url, do: "https://#{domain()}.auth0.com/oauth/token"
  def domain, do: get_config(:domain)

  def mgmt_token do
    case get_config(:mgmt_token) do
      token when is_binary(token) -> token

      _ ->
        get_token_from_client()
    end
  end

  def http_opts, do: get_config(:http_opts) || []
  def ua, do: get_config(:user_agent) || "Auth0Ex <https://github.com/techgaun/auth0_ex>"
  def req_header, do: [{"User-Agent", ua()},
                       {"Authorization", "Bearer #{mgmt_token()}"},
                       {"Content-Type", "application/json"}]

  defp get_config(key), do: Application.get_env(:auth0_ex, key)

  defp get_token_from_client do
    case TokenState.get(:mgmt_token) do
      token when is_binary(token) ->
        if expired?(token) do
          fetch_mgmt_token()
        else
          token
        end

      _ ->
        fetch_mgmt_token()
    end
  end

  defp fetch_mgmt_token do
    client_id = get_config(:mgmt_client_id)
    client_secret = get_config(:mgmt_client_secret)
    payload = %{
      "client_id" => client_id,
      "client_secret" => client_secret,
      "audience" => base_url(),
      "grant_type" => "client_credentials"
    }

    header = [{"Content-Type", "application/json"}]

    token =
      oauth_url()
      |> HTTPoison.post!(Poison.encode!(payload), header, http_opts())
      |> Map.from_struct
      |> Map.get(:body)
      |> Poison.decode!()
      |> Map.get("access_token")

    TokenState.put(:mgmt_token, token)
    token
  end

  defp expired?(token) do
    token
    |> String.split(".")
    |> Enum.at(1)
    |> Base.decode64!(padding: false)
    |> Poison.decode!()
    |> Map.get("exp")
    |> Kernel.<(DateTime.utc_now |> DateTime.to_unix)
  end
end
