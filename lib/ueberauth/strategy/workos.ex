defmodule Ueberauth.Strategy.WorkOS do
  @moduledoc """
  Implementation of an Ueberauth Strategy for WorkOS Single Sign-On

  ## Configuration

  This provider supports the following configuration:

    * `api_key`: (**Required**) WorkOS API key, which also acts as the OAuth client secret. This key
      is environment-specific and may be supplied using runtime configuration.

    * `client_id`: (**Required**) OAuth client ID obtained from WorkOS. This ID is
      environment-specific and may be supplied using runtime configuration.

  """
  use Ueberauth.Strategy

  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Extra
  alias Ueberauth.Auth.Info

  @doc false
  @impl Ueberauth.Strategy
  def uid(conn), do: conn.params["profile"]["id"]

  @doc false
  @impl Ueberauth.Strategy
  def credentials(conn) do
    expiration = DateTime.utc_now() |> DateTime.add(10 * 60, :second) |> DateTime.to_unix()

    %Credentials{
      expires: true,
      expires_at: expiration,
      token: conn.params["access_token"],
      token_type: "access_token"
    }
  end

  @doc false
  @impl Ueberauth.Strategy
  def extra(conn) do
    %Extra{
      raw_info: conn.params["profile"]
    }
  end

  @doc false
  @impl Ueberauth.Strategy
  def info(conn) do
    %Info{
      email: conn.params["profile"]["email"],
      first_name: conn.params["profile"]["first_name"],
      last_name: conn.params["profile"]["last_name"]
    }
  end
end
