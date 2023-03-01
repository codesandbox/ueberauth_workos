Much of the setup for this strategy will be familiar if you have integrated with other Ueberauth strategies.
However, there is one additional step necessary: a redirect or plug that supplies connection information to the request phase.

## Set Up with WorkOS

> #### Note {:.info}
>
> If you already have an API Key and Client ID from the WorkOS [dashboard](https://dashboard.workos.com/get-started) and SSO configuration, skip down to [Installation](#installation).

You can also check out the [official documentation](https://workos.com/docs/reference/sso) for WorkOS Single Sign-On.

**Prerequisites**

* You must have a WorkOS account with **Developer** or **Admin** permissions.
* You must use the `Developer` or `Staging` environment in order to test with `http://` or `localhost` redirect URLs.
* You must give billing information in order to use the `Production` environment.

In order to configure this Ueberauth strategy, you will need two pieces of information from the WorkOS dashboard:

1. **API Key**: On the [dashboard](https://dashboard.workos.com/get-started), select **API Keys** in the left sidebar.
  Check that you are on the correct environment in the top-left.
  Copy the **Secret key**.

2. **Client ID**: On the [dashboard](https://dashboard.workos.com/get-started), select **Configuration** in the left sidebar.
  Check that you are on the correct environment in the top-left.
  Copy the **Client ID**.

In addition, you must supply at least one **Redirect URI** on the same page where you copied the Client ID.
This can be an `http://` or `localhost` URL only if you are in the staging or development environment.
Otherwise it must be a fully-qualified hostname that uses HTTPS.
The entered URL should match **exactly** what you intend to use as the callback URL.
For example:

```plain
http://localhost:4000/auth/workos/callback
https://example.com/auth/workos/callback
```

---

## Installation

With the two environment-specific secrets available, and the Redirect URI set up, you are ready to install and configure the strategy.

### Package

Add `ueberauth_workos` as a dependency in `mix.exs` and run `mix deps.get`.
This package is not yet available on Hex.pm.
In the meantime, you can install it directly from GitHub:

```elixir
def deps do
  [
    {:ueberauth, "~> 0.10"},
    {:ueberauth_workos, github: "codesandbox/ueberauth_workos"}
  ]
end
```

### Provider Configuration

Then add this library as a provider in your configuration for Ueberauth:

```elixir
config :ueberauth, Ueberauth,
  providers: [
    workos: {Ueberauth.Strategy.WorkOS, []}
  ]
```

Unlike many other OAuth-based strategies, this library does not accept many options in the provider definition.
The following configuration is optional:

* `callback_url`: Redirect URI to send users for the callback phase of OAuth. This URL must be
  allowed in the WorkOS configuration for the environment matching the client ID. By default,
  Ueberauth will construct a callback URL using the Phoenix endpoint host and the provider name.

### OAuth Configuration

This strategy requires two pieces of configuration.
Because these values are likely to change between environments, and should be kept secret, we recommend using runtime configuration (for example, `config/runtime.exs`).

* `api_key`: (**Required**) WorkOS API key, which also acts as the OAuth client secret. This key
  is environment-specific and must match the environment of the `client_id`..

* `client_id`: (**Required**) OAuth client ID obtained from WorkOS. This ID is environment-specific
  and must match the environment of the `api_key`.

You may include these options directly in the provider configuration, if it occurs in the appropriate configuration file:

```elixir
config :ueberauth, Ueberauth,
  providers: [
    workos: {Ueberauth.Strategy.WorkOS, [
      api_key: System.fetch_env!("WORKOS_API_KEY"),
      client_id: System.fetch_env!("WORKOS_CLIENT_ID")
    ]}
  ]
```

Alternatively, you may configure the strategy module directly.
This can be useful if you wish to place this in a separate configuration file:

```elixir
config :ueberauth, Ueberauth.Strategy.WorkOS,
  api_key: System.fetch_env!("WORKOS_API_KEY"),
  client_id: System.fetch_env!("WORKOS_CLIENT_ID")
```

**Remember**: It is recommended to use runtime configuration for the API key and client ID.

---

## Integration

Much of the setup for this strategy will be familiar if you have integrated with other Ueberauth strategies.
However, there is one additional step necessary: a redirect or plug that supplies connection information to the request phase.

### Plug Integration

As with other Ueberauth providers, it is necessary to implement handlers for the callback phase.
This usually includes adding `Ueberauth` as a plug in an authentication-related controller:

```elixir
defmodule MyAppWeb.AuthController do
  use MyAppWeb, :controller
  plug Ueberauth
  # ...
end
```

Then, implement handlers for success and failure cases during the callback phase:

```elixir
defmodule MyAppWeb.AuthController do
  # ...

  def callback(%{assigns: %{ueberauth_failure: failure}} = conn, _params) do
    message = Enum.map_join(failure.errors, "; ", fn error -> error.message end)

    conn
    |> put_flash(:error, "An error occurred during authentication: #{message}")
    |> redirect(to: "/")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case MyApp.Accounts.create_or_update_user(auth) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Successfully logged in")
        |> log_in_and_redirect_user(user)

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "An error occurred while saving login")
        |> redirect(to: "/")
    end
  end
end
```

Finally, ensure the relevant routes are available in the router:

```elixir
defmodule MyAppWeb.Router
  # ...

  scope "/auth", UeberauthExampleWeb do
    pipe_through :browser

    get "/:provider", AuthController, :request

    # Include this for requests with no scopes, or if you use other providers that require it.
    get "/:provider/callback", AuthController, :callback

    # Include this for requests with any scopes (name and/or email).
    post "/:provider/callback", AuthController, :callback
  end
end
```

For further assistance, check out the [Ueberauth Example](https://github.com/ueberauth/ueberauth_example).

### Connection Selector

Unique to this strategy is the need for a _Connection Selector_ during the request phase.
WorkOS describes it thusly:

> To indicate the connection to use for authentication, use one of the following connection
> selectors: connection, organization, or provider.
>
> These connection selectors are mutually exclusive, and exactly one must be provided.

Therefore, the request phase must include exactly one of `connection`, `organization`, or `provider` in the incoming params.
These may be provided directly by the client, or inserted before Ueberauth runs (before `plug Ueberauth`) by a custom plug.
If absent, the request will fail immediately.

This is the point where you ask a user what organization they belong to before redirecting them to log in.
Many applications do this using a discrete "Sign In with SSO" button and collecting the user's email address.
Then, using the email address domain or an existing user record, the user is redirected to the request phase with the additional _Connection Selector_ parameter.

This library does not care which type of selector you use.
Only one can be provided to WorkOS, so it will use the `connection`, `organization`, or `provider` in order.

#### Example: Redirect to Request Phase

In this example, we will use a separate endpoint to initiate the sign-in flow.
We can conceptually think of this as a new first phase of the OAuth process called "initialize".

In our router, we will need a separate route:

```elixir
scope "/auth", MyAppWeb do
  # ...

  get("/workos/initialize", AuthController, :initialize)
  get("/:provider", AuthController, :request)
  get("/:provider/callback", AuthController, :callback)
end
```

Then, in our controller, we accept the incoming user email and look up the corresponding user's WorkOS connection, organization, or provider.

```elixir
def initialize(conn, %{"email" => email}) do
  case find_user_by_email(email) do
    {:ok, %{workos_connection: connection_id}} ->
      redirect(to: "/auth/workos?connection=#{connection_id}")

    _else ->
      conn
      |> put_flash(:error, "SSO is not enabled for this email address")
      |> redirect(to: "/login")
  end
end
```

Once redirected to the request phase endpoint with the connection selector param, Ueberauth will take over the interaction and return the user to your callback handler once complete.

#### Example: Plug before Request Phase

It is also possible to handle the email-to-connection-selector conversion using a Plug that runs before Ueberauth takes over the request phase.
In order to accomplish this, the custom plug must run before `plug Ueberauth` for the request phase action.

A full example is not included here, however it should end with a new param `connection`, `organization`, or `provider` present in the connection struct as it is handed off to Ueberauth.

### Additional Parameters

You may optionally send the following parameters to the request phase in addition to the _Connection Selector_ described above:

* `domain_hint`: According to WorkOS: _Can be used to pre-fill the domain field when initiating
  authentication with Microsoft OAuth, or with a `GoogleSAML` connection type._

* `login_hint`: According to WorkOS: _Can be used to pre-fill the username/email address field of
  the IdP sign-in page for the user, if you know their username ahead of time._
