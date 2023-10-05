# Ueberauth WorkOS

[![Hex.pm](https://img.shields.io/hexpm/v/ueberauth_workos)](https://hex.pm/packages/ueberauth_workos)
[![Documentation](https://img.shields.io/badge/hex-docs-blue)](https://hexdocs.pm/ueberauth_workos)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](CODE_OF_CONDUCT.md)

Ueberauth strategy for integrating with WorkOS Single Sign-On

## Quick Start

For detailed instructions, see [Getting Started](guides/getting-started.md).

### Installation

Add `ueberauth_workos` as a dependency in `mix.exs` and run `mix deps.get`:

```elixir
def deps do
  [
    {:ueberauth, "~> 0.10"},
    {:ueberauth_workos, "~> 0.0.3"}
  ]
end
```

**Warning**: This package is in early development, and not suitable for production use.

### Configuration

This strategy requires two pieces of configuration.
Because these values are likely to change between environments, and should be kept secret, we recommend using runtime configuration (for example, `config/runtime.exs`).

* `api_key`: (**Required**) WorkOS API key, which also acts as the OAuth client secret. This key
  is environment-specific and must match the environment of the `client_id`..

* `client_id`: (**Required**) OAuth client ID obtained from WorkOS. This ID is environment-specific
  and must match the environment of the `api_key`.

The following configuration is optional:

* `callback_url`: Redirect URI to send users for the callback phase of OAuth. This URL must be
  allowed in the WorkOS configuration for the environment matching the client ID. By default,
  Ueberauth will construct a callback URL using the Phoenix endpoint host and the provider name.

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

### Integration

Much of the setup for this strategy will be familiar if you have integrated with other Ueberauth strategies.
However, there is one additional step necessary: a redirect or plug that supplies connection information to the request phase.

Unique to this strategy is the need for a _Connection Selector_ during the request phase.
For detailed instructions, see [Getting Started](guides/getting-started.md).

## License

Please see [LICENSE](LICENSE) for licensing details.
