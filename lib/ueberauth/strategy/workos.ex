defmodule Ueberauth.Strategy.WorkOS do
  @moduledoc """
  Implementation of an Ueberauth Strategy for WorkOS Single Sign-On

  ## Configuration

  This provider supports the following configuration:

    * `api_key`: (**Required**) WorkOS API key, which also acts as the OAuth client secret. This key
      is environment-specific and may be supplied using runtime configuration.

    * `callback_url`: Redirect URI to send users for the callback phase. This URL
      must be allowed in the WorkOS configuration for the environment matching the Client ID.
      Defaults to a callback URL calculated using the endpoint host and provider name.

    * `client_id`: (**Required**) OAuth client ID obtained from WorkOS. This ID is
      environment-specific and may be supplied using runtime configuration.

  Example configuration:

      # config/runtime.exs
      config :ueberauth, Ueberauth.Strategy.WorkOS,
        api_key: System.fetch_env!("WORKOS_API_KEY"),
        client_id: System.fetch_env!("WORKOS_CLIENT_ID")

  """
  use Ueberauth.Strategy

  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Extra
  alias Ueberauth.Auth.Info
  alias Ueberauth.Strategy.WorkOS.OAuth

  #
  # Plug Callbacks
  #

  @doc false
  @impl Ueberauth.Strategy
  def handle_request!(conn) do
    params =
      []
      |> with_connection_selector(conn)
      |> with_param(:domain_hint, conn)
      |> with_param(:login_hint, conn)
      |> with_state_param(conn)

    opts = oauth_client_options_from_conn(conn)
    redirect!(conn, OAuth.authorize_url!(params, opts))
  end

  @doc false
  @impl Ueberauth.Strategy
  def handle_callback!(%Plug.Conn{params: %{"code" => code}} = conn) do
    params = [code: code]

    conn
    |> oauth_client_options_from_conn()
    |> OAuth.client()
    |> OAuth2.Client.get_token(params)
    |> case do
      {:ok,
       %OAuth2.Client{token: %OAuth2.AccessToken{other_params: %{"profile" => profile}} = token}} ->
        conn
        |> put_private(:workos_profile, profile)
        |> put_private(:workos_token, token)

      {:error, %OAuth2.Response{body: %{"error" => error, "error_description" => description}}} ->
        {:error, {error, description}}

      {:error, %OAuth2.Error{reason: reason}} ->
        {:error, {"error", to_string(reason)}}
    end
  end

  @doc false
  @impl Ueberauth.Strategy
  def handle_cleanup!(conn) do
    conn
    |> put_private(:workos_profile, nil)
    |> put_private(:workos_token, nil)
  end

  #
  # Data Processing Callbacks
  #

  @doc false
  @impl Ueberauth.Strategy
  def uid(conn), do: conn.private[:workos_profile]["id"]

  @doc false
  @impl Ueberauth.Strategy
  def credentials(conn) do
    expiration = DateTime.utc_now() |> DateTime.add(10 * 60, :second) |> DateTime.to_unix()

    %Credentials{
      expires: true,
      expires_at: expiration,
      token: conn.private[:workos_token].access_token,
      token_type: "access_token"
    }
  end

  @doc false
  @impl Ueberauth.Strategy
  def extra(conn) do
    %Extra{
      raw_info: conn.private[:workos_profile]
    }
  end

  @doc false
  @impl Ueberauth.Strategy
  def info(conn) do
    %Info{
      email: conn.private[:workos_profile]["email"],
      first_name: conn.private[:workos_profile]["first_name"],
      last_name: conn.private[:workos_profile]["last_name"]
    }
  end

  #
  # Helpers
  #

  @spec with_connection_selector(keyword, Plug.Conn.t()) :: keyword
  defp with_connection_selector(params, conn) do
    case conn.private do
      %{workos_connection: connection_id} -> Keyword.put(params, :connection, connection_id)
      %{workos_organization: org_id} -> Keyword.put(params, :organization, org_id)
      %{workos_provider: provider} -> Keyword.put(params, :provider, provider)
      _else -> raise "Missing WorkOS connection, organization, or provider"
    end
  end

  @spec with_param(keyword, atom, Plug.Conn.t()) :: keyword
  defp with_param(params, key, conn) do
    if value = conn.params[to_string(key)], do: Keyword.put(params, key, value), else: params
  end

  @spec oauth_client_options_from_conn(Plug.Conn.t()) :: keyword
  defp oauth_client_options_from_conn(conn) do
    base_options = [redirect_uri: callback_url(conn)]
    request_options = conn.private[:ueberauth_request_options].options

    case {request_options[:client_id], request_options[:api_key]} do
      {nil, _} -> base_options
      {_, nil} -> base_options
      {id, secret} -> [client_id: id, client_secret: secret] ++ base_options
    end
  end
end
