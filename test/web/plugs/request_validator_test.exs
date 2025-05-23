defmodule Utilex.Web.Plugs.RequestValidatorTest do
  use ExUnit.Case

  import Phoenix.ConnTest
  import Plug.Conn
  import Plug.Test

  alias Utilex.Web.Plugs.RequestValidator

  defmodule Users do
    use Ecto.Schema

    import Ecto.Changeset

    alias __MODULE__

    schema "users" do
      field(:name, :string)
      field(:email, :string)
    end

    def create(params) do
      %Users{}
      |> cast(params, ~w(name email)a)
      |> validate_required(~w(name email)a)
    end
  end

  describe "call/2" do
    setup do
      Application.delete_env(:utilex, :web_request_validator)
      opts = RequestValidator.init(validator: Users)
      params = %{"name" => "Joe Doe", "email" => "joe.doe@mail.com"}
      %{opts: opts, params: params}
    end

    test "should return a conn with state :unset when the data is successfully validated",
         %{opts: opts, params: valid_params} do
      conn =
        conn(:post, "/api/users", valid_params)
        |> put_req_header("content-type", "application/json")
        |> put_private(:phoenix_action, :create)
        |> RequestValidator.call(opts)

      assert conn.state == :unset
    end

    test "should return a conn with state :unset when validator does not have a validate function",
         %{opts: opts, params: valid_params} do
      conn =
        conn(:post, "/api/users", valid_params)
        |> put_req_header("content-type", "application/json")
        |> put_private(:phoenix_action, :update)
        |> RequestValidator.call(opts)

      assert conn.state == :unset
    end

    test "should return a conn with status :bad_request when the data is invalid",
         %{opts: opts, params: params} do
      invalid_params = Map.delete(params, "name")

      conn =
        conn(:post, "/api/users", invalid_params)
        |> put_req_header("content-type", "application/json")
        |> put_private(:phoenix_action, :create)
        |> RequestValidator.call(opts)

      assert ["application/problem+json"] == get_resp_header(conn, "content-type")

      assert %{
               "errors" => [%{"field" => "name", "reason" => "can't be blank"}],
               "title" => "Your request parameters didn't validate.",
               "type" => "https://example.net/validation_error"
             } == json_response(conn, :bad_request)
    end

    test "should return a conn with status :bad_request when the data is invalid and a custom error_title is configured",
         %{opts: opts, params: params} do
      Application.put_env(:utilex, :web_request_validator, error_title: "Validation error")

      invalid_params = Map.delete(params, "name")

      conn =
        conn(:post, "/api/users", invalid_params)
        |> put_req_header("content-type", "application/json")
        |> put_private(:phoenix_action, :create)
        |> RequestValidator.call(opts)

      assert %{"title" => "Validation error"} = json_response(conn, :bad_request)
    end

    test "should return a conn with status :bad_request when the data is invalid and a custom error_type is configured",
         %{opts: opts, params: params} do
      Application.put_env(:utilex, :web_request_validator, error_type: "https://my_domain/validation_error")

      invalid_params = Map.delete(params, "name")

      conn =
        conn(:post, "/api/users", invalid_params)
        |> put_req_header("content-type", "application/json")
        |> put_private(:phoenix_action, :create)
        |> RequestValidator.call(opts)

      assert %{"type" => "https://my_domain/validation_error"} = json_response(conn, :bad_request)
    end
  end
end
