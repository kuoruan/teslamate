defmodule TeslaMateWeb.LocationController do
  use TeslaMateWeb, :controller

  alias TeslaMate.Locations.Geocoder

  def geocoder_reverse(conn, %{"lat" => lat, "lon" => lon} = params) do
    lang = Map.get(params, "lang", "en")

    case {Float.parse(lat), Float.parse(lon)} do
      {{lat, ""}, {lon, ""}} ->
        case Geocoder.reverse_lookup(lat, lon, lang) do
          {:ok, address} ->
            json(conn, address)

          {:error, reason} ->
            conn
            |> put_status(:bad_request)
            |> json(%{error: reason})
        end

      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid latitude or longitude"})
    end
  end

  def geocoder_reverse(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing latitude or longitude"})
  end
end
