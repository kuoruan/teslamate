defmodule TeslaMateWeb.MapsController do
  use TeslaMateWeb, :controller

  alias TeslaMate.Maps

  def tile(conn, %{"zoom" => zoom, "x" => x, "y" => y} = params) do
    with {zoom, ""} <- Integer.parse(zoom),
         {x, ""} <- Integer.parse(x),
         {y, ""} <- Integer.parse(y) do
      opts = Map.drop(params, ["zoom", "x", "y"])

      case Maps.tile_image(zoom, x, y, conn.req_headers, opts) do
        {:ok, status, body, response_headers} ->
          conn
          |> put_upstream_resp_headers(response_headers)
          |> send_resp(status, body)

        {:error, _} ->
          send_resp(conn, 404, "Not found")
      end
    else
      _ -> send_resp(conn, 404, "Not found")
    end
  end

  # Helper to set response headers from upstream
  defp put_upstream_resp_headers(conn, headers) do
    Enum.reduce(headers, conn, fn {name, value}, acc ->
      adjusted_value =
        case {String.downcase(name), value} do
          # 如果响应头为 content-type，并且值为 application/octet-stream，设置为 image/png
          {"content-type", "application/octet-stream"} -> "image/png"
          _ -> value
        end

      put_resp_header(acc, name, adjusted_value)
    end)
  end
end
