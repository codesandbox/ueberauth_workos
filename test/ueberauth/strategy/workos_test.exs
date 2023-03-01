defmodule Ueberauth.Strategy.WorkOSTest do
  use ExUnit.Case, async: false
  use Plug.Test
  import Mock

  alias Ueberauth.Strategy.WorkOS

  setup_with_mocks([
    {OAuth2.Client, [:passthrough],
     [
       get_token: fn _client, _params ->
         {:ok,
          %OAuth2.Client{
            token: %OAuth2.AccessToken{
              access_token: "access-abc123",
              expires_at: 1_662_751_328,
              other_params: %{
                "profile" => %{
                  "object" => "profile",
                  "id" => "prof_01DMC79VCBZ0NY2099737PSVF1",
                  "connection_id" => "conn_01E4ZCR3C56J083X43JQXF3JK5",
                  "connection_type" => "OktaSAML",
                  "organization_id" => "org_01EHWNCE74X7JSDV0X3SZ3KJNY",
                  "email" => "todd@foo-corp.com",
                  "first_name" => "Todd",
                  "last_name" => "Rundgren",
                  "idp_id" => "00u1a0ufowBJlzPlk357",
                  "raw_attributes" => %{}
                }
              },
              refresh_token: nil,
              token_type: "Bearer"
            }
          }}
       end
     ]}
  ]) do
    %{}
  end

  describe "handle_request!/1" do
    setup do
      conn =
        conn(:get, "/auth/workos", %{"connection" => "conn_01E4ZCR3C56J083X43JQXF3JK5"})
        |> put_private(:ueberauth_request_options, %{
          callback_methods: ["GET"],
          callback_params: nil,
          callback_path: "/auth/workos/callback",
          callback_port: nil,
          callback_scheme: nil,
          callback_url: "https://my-app.example.com/auth/workos/callback",
          options: [
            api_key: "api-key-abc123",
            client_id: "client_abc123"
          ],
          request_path: "/auth/workos",
          request_port: nil,
          request_scheme: nil,
          strategy: Ueberauth.Strategy.WorkOS,
          strategy_name: :workos
        })
        |> put_private(:ueberauth_state_param, "state-abc123")
        |> put_resp_cookie("ueberauth.state_param", "state-abc123")

      %{conn: conn}
    end

    test "redirects to WorkOS sign-in", %{conn: conn} do
      conn = WorkOS.handle_request!(conn)
      assert {302, headers, _body} = sent_resp(conn)
      assert %{"location" => sign_in_page} = Enum.into(headers, %{})
      assert sign_in_page =~ "https://api.workos.com/sso/authorize"
    end

    # Connection Selector

    # Other Params

    test "allows a custom domain_hint parameter", %{conn: conn} do
      conn = put_param(conn, "domain_hint", "example.com")
      conn = WorkOS.handle_request!(conn)
      assert {302, headers, _body} = sent_resp(conn)
      assert %{"location" => sign_in_page} = Enum.into(headers, %{})
      assert sign_in_page =~ "domain_hint=example.com"
    end

    test "allows a custom login_hint parameter", %{conn: conn} do
      conn = put_param(conn, "login_hint", "me@example.com")
      conn = WorkOS.handle_request!(conn)
      assert {302, headers, _body} = sent_resp(conn)
      assert %{"location" => sign_in_page} = Enum.into(headers, %{})
      assert sign_in_page =~ "login_hint=me%40example.com"
    end

    # State

    test "sets state cookie", %{conn: conn} do
      conn = WorkOS.handle_request!(conn)
      assert {_status, headers, _body} = sent_resp(conn)
      assert %{"location" => sign_in_page, "set-cookie" => cookie} = Enum.into(headers, %{})
      assert cookie =~ "ueberauth.state_param=state-abc123"
      assert sign_in_page =~ "state=state-abc123"
    end

    # Client

    test "sets client ID based on configuration", %{conn: conn} do
      conn = WorkOS.handle_request!(conn)
      assert {302, headers, _body} = sent_resp(conn)
      assert %{"location" => sign_in_page} = Enum.into(headers, %{})
      assert sign_in_page =~ "client_id=client_abc123"
    end

    # Redirect URI

    test "sets redirect URI based on configuration", %{conn: conn} do
      conn = WorkOS.handle_request!(conn)
      assert {302, headers, _body} = sent_resp(conn)
      assert %{"location" => sign_in_page} = Enum.into(headers, %{})

      assert sign_in_page =~
               "redirect_uri=https%3A%2F%2Fmy-app.example.com%2Fauth%2Fworkos%2Fcallback"
    end
  end

  describe "handle_callback!/1" do
    setup do
      conn =
        conn(:get, "/auth/workos/callback", %{
          "code" => "code-abc123",
          "state" => "state-abc123"
        })
        |> put_private(:ueberauth_request_options, %{
          callback_methods: ["GET"],
          callback_params: nil,
          callback_path: "/auth/workos/callback",
          callback_port: nil,
          callback_scheme: nil,
          callback_url: "https://my-app.example.com/auth/workos/callback",
          options: [
            api_key: "api-key-abc123",
            client_id: "client_abc123"
          ],
          request_path: "/auth/workos",
          request_port: nil,
          request_scheme: nil,
          strategy: Ueberauth.Strategy.WorkOS,
          strategy_name: :workos
        })

      %{conn: conn}
    end

    test "handles an error response", %{conn: conn} do
      conn = %{conn | params: %{"error" => "some error"}}
      conn = WorkOS.handle_callback!(conn)
      assert conn.assigns[:ueberauth_failure]
    end

    test "retrieves WorkOS user and token", %{conn: conn} do
      conn = WorkOS.handle_callback!(conn)
      assert %{"id" => "prof_01DMC79VCBZ0NY2099737PSVF1"} = conn.private[:workos_profile]
      assert %OAuth2.AccessToken{access_token: "access-abc123"} = conn.private[:workos_token]
    end
  end

  describe "cleanup" do
    setup do
      conn =
        conn(:get, "/auth/workos/callback", %{
          "code" => "code-abc123",
          "state" => "state-abc123"
        })
        |> put_private(:ueberauth_request_options, %{
          callback_methods: ["GET"],
          callback_params: nil,
          callback_path: "/auth/workos/callback",
          callback_port: nil,
          callback_scheme: nil,
          callback_url: "https://my-app.example.com/auth/workos/callback",
          options: [
            api_key: "api-key-abc123",
            client_id: "client_abc123"
          ],
          request_path: "/auth/workos",
          request_port: nil,
          request_scheme: nil,
          strategy: Ueberauth.Strategy.WorkOS,
          strategy_name: :workos
        })
        |> put_private(:workos_profile, %{
          "object" => "profile",
          "id" => "prof_01DMC79VCBZ0NY2099737PSVF1",
          "connection_id" => "conn_01E4ZCR3C56J083X43JQXF3JK5",
          "connection_type" => "OktaSAML",
          "organization_id" => "org_01EHWNCE74X7JSDV0X3SZ3KJNY",
          "email" => "todd@foo-corp.com",
          "first_name" => "Todd",
          "last_name" => "Rundgren",
          "idp_id" => "00u1a0ufowBJlzPlk357",
          "raw_attributes" => %{}
        })
        |> put_private(:workos_token, %OAuth2.AccessToken{
          access_token: "access-abc123",
          expires_at: 1_662_751_328,
          other_params: %{
            "profile" => %{
              "object" => "profile",
              "id" => "prof_01DMC79VCBZ0NY2099737PSVF1",
              "connection_id" => "conn_01E4ZCR3C56J083X43JQXF3JK5",
              "connection_type" => "OktaSAML",
              "organization_id" => "org_01EHWNCE74X7JSDV0X3SZ3KJNY",
              "email" => "todd@foo-corp.com",
              "first_name" => "Todd",
              "last_name" => "Rundgren",
              "idp_id" => "00u1a0ufowBJlzPlk357",
              "raw_attributes" => %{}
            }
          },
          refresh_token: nil,
          token_type: "Bearer"
        })

      %{conn: conn}
    end

    test "collects UID, credentials, and info", %{conn: conn} do
      assert WorkOS.uid(conn) == "prof_01DMC79VCBZ0NY2099737PSVF1"

      assert %Ueberauth.Auth.Credentials{
               expires: true,
               token: "access-abc123",
               token_type: "access_token"
             } = WorkOS.credentials(conn)

      assert %Ueberauth.Auth.Info{
               email: "todd@foo-corp.com",
               first_name: "Todd",
               last_name: "Rundgren"
             } = WorkOS.info(conn)
    end

    test "cleans up temporary data", %{conn: conn} do
      conn = WorkOS.handle_cleanup!(conn)
      refute conn.private[:workos_profile]
      refute conn.private[:workos_token]
    end
  end

  defp put_param(conn, key, value) do
    params = Map.put(conn.params, key, value)
    %Plug.Conn{conn | params: params}
  end
end
