defmodule TeslaMateWeb.MapController do
  use TeslaMateWeb, :controller
  import Bitwise

  alias TeslaMate.Maps.Tile

  @max_zoom 22

  def tile(conn, %{"zoom" => zoom, "x" => x, "y" => y} = params) do
    with {zoom, ""} <- Integer.parse(zoom),
         {x, ""} <- Integer.parse(x),
         {y, ""} <- Integer.parse(y),
         true <- zoom in 0..@max_zoom,
         true <- x in 0..(bsl(1, zoom) - 1),
         true <- y in 0..(bsl(1, zoom) - 1) do
      opts = Map.drop(params, ["zoom", "x", "y"])

      case Tile.get_image(zoom, x, y, conn.req_headers, opts) do
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

  # 只透传安全的上游响应头，避免 set-cookie 等敏感头跨域下发
  @passthrough_headers ~w(
    content-type
    content-length
    etag
    last-modified
    cache-control
    expires
    pragma
    age
  )

  defp put_upstream_resp_headers(conn, headers) do
    Enum.reduce(headers, conn, fn {name, value}, acc ->
      if String.downcase(name) in @passthrough_headers do
        adjusted_value =
          case {String.downcase(name), value} do
            {"content-type", "application/octet-stream"} -> "image/png"
            _ -> value
          end

        put_resp_header(acc, name, adjusted_value)
      else
        acc
      end
    end)
  end
end
