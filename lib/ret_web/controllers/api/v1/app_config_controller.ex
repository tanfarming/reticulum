defmodule RetWeb.Api.V1.AppConfigController do
  use RetWeb, :controller
  alias Ret.{Repo, AppConfig, Storage, OwnedFile}

  def create(conn, _params) do
    {:ok, body, conn} = conn |> Plug.Conn.read_body()

    # We expect the request body to be a json object where the leaf nodes are the config values.
    collapsed_config = body |> Poison.decode!() |> AppConfig.collapse()

    account = Guardian.Plug.current_resource(conn)

    collapsed_config
    |> Enum.each(fn {key, val} ->
      app_config = AppConfig |> Repo.get_by(key: key) || %AppConfig{}

      app_config =
        case val do
          %{"file_id" => file_id, "meta" => %{"access_token" => access_token, "promotion_token" => promotion_token}} ->
            {:ok, owned_file} = Storage.promote(file_id, access_token, promotion_token, account)
            file_uri = owned_file |> OwnedFile.uri_for() |> URI.to_string()
            app_config |> AppConfig.changeset(owned_file, %{key: key, value: file_uri})

          _ ->
            app_config |> AppConfig.changeset(%{key: key, value: val})
        end

      app_config |> Repo.insert_or_update!()
    end)

    conn |> send_resp(200, "")
  end

  def index(conn, _params) do
    conn |> send_resp(200, AppConfig.get_config() |> Poison.encode!())
  end
end
