defmodule Ueberauth.Strategy.WorkOS.OAuth do
  @moduledoc """
  Implementation of an OAuth 2.0 strategy for WorkOS Single Sign-On

  > #### Note {:.info}
  > This module is not intended to be called or configured directly. Please see
  > `Ueberauth.Strategy.WorkOS` for all relevant configuration and documentation.

  ## Configuration

  This module uses the configuration defined in `Ueberauth.Strategy.WorkOS`. Unlike other Ueberauth
  strategies, there is no need to define application environment variables for this module.
  """
  use OAuth2.Strategy

  @defaults [
    authorize_url: "https://api.workos.com/sso/authorize",
    headers: [{"user-agent", "ueberauth_workos"}],
    site: "https://api.workos.com",
    strategy: __MODULE__,
    token_url: "https://api.workos.com/sso/token"
  ]

  #
  # Ueberauth Strategy Helpers
  #

  @doc """
  Construct a client for requests to the WorkOS API

  ## Options

  This function accepts the same options as `OAuth2.Client.new/1`, including a `redirect_uri`. All
  options are collected and merged in this way:

    * Options passed directly to this function have the highest precedence, overriding all others.
    * Options configured with `Ueberauth.Strategy.WorkOS` have next-highest priority.
    * There are default values for `authorize_url`, `headers`, `site`, and `token_url`.

  OAuth2 will use the same JSON serialization library as returned by `Ueberauth.json_library/0`.
  """
  @spec client(keyword) :: OAuth2.Client.t()
  def client(opts \\ []) do
    config = Application.get_env(:ueberauth, Ueberauth.Strategy.WorkOS) || []

    client_opts =
      @defaults
      |> Keyword.merge(config)
      |> Keyword.merge(opts)
      |> check_credential(:client_id)
      |> check_credential(:api_key, :client_secret)

    json_library = Ueberauth.json_library()

    client_opts
    |> OAuth2.Client.new()
    |> OAuth2.Client.put_serializer("application/json", json_library)
  end

  @spec check_credential(keyword, atom, atom) :: keyword
  defp check_credential(config, key, rename_to \\ nil) do
    validate_key_exists(config, key)

    case Keyword.get(config, key) do
      value when is_binary(value) ->
        if rename_to do
          config
          |> Keyword.delete(key)
          |> Keyword.put(rename_to, value)
        else
          config
        end

      {:system, env_key} ->
        case System.get_env(env_key) do
          nil ->
            raise """
            Missing environment variable #{inspect(env_key)} in configuration for Ueberauth.Strategy.WorkOS

            This variable is configured for the #{inspect(key)} key.
            """

          value ->
            new_key_name = rename_to || key
            Keyword.put(config, new_key_name, value)
        end

      value ->
        raise """
        Invalid value for required key #{inspect(key)} in configuration for Ueberauth.Strategy.WorkOS

        This value must be a string, got: #{inspect(value)}
        """
    end
  end

  @spec validate_key_exists(keyword, atom) :: keyword | no_return
  defp validate_key_exists(config, key) when is_list(config) do
    unless Keyword.has_key?(config, key) do
      raise """
      Missing required key #{inspect(key)} in configuration for Ueberauth.Strategy.WorkOS

      Example configuration:

          config :ueberauth, Ueberauth,
            providers: [
              workos: {Ueberauth.Strategy.WorkOS, [
                api_key: "...",
                client_id: "..."
              ]}
            ]

      OR

          config :ueberauth, Ueberauth.Strategy.WorkOS,
            api_key: "...",
            client_id: "..."

      """
    end

    config
  end

  @doc "Get the authorization URL used during the request phase of Ueberauth"
  @spec authorize_url!(keyword, keyword) :: String.t()
  def authorize_url!(params \\ [], opts \\ []) do
    opts
    |> client()
    |> OAuth2.Client.authorize_url!(params)
  end

  #
  # OAuth2 Strategy Callbacks
  #

  @doc false
  @impl OAuth2.Strategy
  def authorize_url(client, params) do
    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  @doc false
  @impl OAuth2.Strategy
  def get_token(client, params, headers) do
    client
    |> put_header("Accept", "application/json")
    |> put_param(:client_secret, client.client_secret)
    |> OAuth2.Strategy.AuthCode.get_token(params, headers)
  end
end
