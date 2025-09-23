defmodule TeslaMateWeb.MapsController do
  use TeslaMateWeb, :controller

  alias TeslaMate.Maps

  def tile(conn, %{"z" => z, "x" => x, "y" => y} = params) do
    with {z, ""} <- Integer.parse(z),
         {x, ""} <- Integer.parse(x),
         {y, ""} <- Integer.parse(y) do
      # Extract optional tileSource from query parameters
      tile_source = Map.get(params, "tileSource")

      opts = if tile_source, do: %{tile_source: tile_source}, else: %{}

      case Maps.tile_image(z, x, y, conn.req_headers, opts) do
        {:ok, image, response_headers} ->
          conn
          |> put_upstream_resp_headers(response_headers)
          |> send_resp(200, image)

        {:error, _} ->
          send_resp(conn, 404, "Not found")
      end
    else
      _ -> send_resp(conn, 404, "Not found")
    end
  end

  # Helper to set response headers from upstream
  defp put_upstream_resp_headers(conn, headers) do
    Enum.reduce(headers, conn, fn
      {name, value}, acc when is_binary(name) and is_binary(value) ->
        put_resp_header(acc, String.downcase(name), value)

      {name, value}, acc when is_binary(value) ->
        put_resp_header(acc, to_string(name), value)

      _, acc ->
        acc
    end)
  end
end
