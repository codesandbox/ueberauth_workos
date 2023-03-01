defmodule Ueberauth.Strategy.WorkOS do
  @moduledoc """
  Implementation of an Ueberauth Strategy for WorkOS Single Sign-On

  ## Configuration

  This provider supports the following configuration:

    * `api_key`: (**Required**) WorkOS API key, which also acts as the OAuth client secret. This key
      is environment-specific and may be supplied using runtime configuration.

    * `client_id`: (**Required**) OAuth client ID obtained from WorkOS. This ID is
      environment-specific and may be supplied using runtime configuration.

    * `callback_url`: Redirect URI to send users for the callback phase. This URL
      must be allowed in the WorkOS configuration for the environment matching the Client ID.
      Defaults to a callback URL calculated using the endpoint host and provider name.

  Example configuration:

      config :ueberauth, Ueberauth,
        providers: [
          workos: {Ueberauth.Strategy.WorkOS, [
            api_key: System.fetch_env!("WORKOS_API_KEY"),
            client_id: System.fetch_env!("WORKOS_CLIENT_ID")
          ]}
        ]

  Alternatively, you may configure the strategy module directly:

      config :ueberauth, Ueberauth.Strategy.WorkOS,
        api_key: System.fetch_env!("WORKOS_API_KEY"),
        client_id: System.fetch_env!("WORKOS_CLIENT_ID")

  ## Connection Selector

  In addition to the configuration mentioned above, the request phase also accepts several params
  allowing the client to specify details of the login process. One of these is the **Connection
  Selector**. The WorkOS documentation states:

  > To indicate the connection to use for authentication, use one of the following connection
  > selectors: connection, organization, or provider.
  >
  > These connection selectors are mutually exclusive, and exactly one must be provided.

  Therefore, the request phase must include exactly one of `connection`, `organization`, or
  `provider` in the incoming params. These may be provided directly by the client, or inserted
  before Ueberauth runs (before `plug Ueberauth`) by a custom plug. If absent, the request will
  fail immediately.

  ## Additional Params

  WorkOS also provides the ability to give "hints" about the domain or login. These hints may also
  be provided by the client or another plug using connection params:

    * `domain_hint`: According to WorkOS: _Can be used to pre-fill the domain field when initiating
      authentication with Microsoft OAuth, or with a `GoogleSAML` connection type._

    * `login_hint`: According to WorkOS: _Can be used to pre-fill the username/email address field
      of the IdP sign-in page for the user, if you know their username ahead of time._

  If you use an email address to determine the connection selector, then it is advisable to use the
  same email address as the `login_hint`.
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
    case conn.params do
      %{"connection" => connection_id} -> Keyword.put(params, :connection, connection_id)
      %{"organization" => org_id} -> Keyword.put(params, :organization, org_id)
      %{"provider" => provider} -> Keyword.put(params, :provider, provider)
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
      {id, secret} -> [client_id: id, api_key: secret] ++ base_options
    end
  end
end
