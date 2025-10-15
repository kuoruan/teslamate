defmodule TeslaMateWeb.LocationController do
  use TeslaMateWeb, :controller

  alias TeslaMate.Settings
  alias TeslaMate.Settings.GlobalSettings
  alias TeslaMate.Locations.Geocoder

  def geocoder_reverse(conn, %{"lat" => lat, "lon" => lon} = params) do
    lang = get_language(conn, params)

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

  # 私有函数：获取语言设置
  # 优先使用 query 参数中的 lang，如果不存在则从 Accept-Language header 获取
  defp get_language(conn, params) do
    %GlobalSettings{language: default_lang} = Settings.get_global_settings!()

    case Map.get(params, "lang") do
      nil ->
        # 从 Accept-Language header 获取首选语言
        case get_req_header(conn, "accept-language") do
          [accept_language | _] ->
            # 解析 Accept-Language header，获取首选语言代码
            parse_accept_language(accept_language, default_lang)

          [] ->
            default_lang
        end

      lang when is_binary(lang) ->
        lang

      _ ->
        default_lang
    end
  end

  # 解析 Accept-Language header，提取首选语言代码
  defp parse_accept_language(accept_language, default_lang) do
    accept_language
    |> String.split(",")
    |> List.first()
    |> case do
      nil ->
        default_lang

      lang_with_quality ->
        lang_with_quality
        |> String.split(";")
        |> List.first()
        |> String.trim()
    end
  end
end
