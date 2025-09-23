defmodule TeslaMate.Maps do
  @moduledoc """
  Provides map tile rendering functionality.

  https://github.com/htoooth/Leaflet.ChineseTmsProviders/blob/master/src/leaflet.ChineseTmsProviders.js
  """

  use Tesla, only: [:get]

  require Logger

  alias TeslaMate.Locations.CoordinateConverter

  @default_headers [
    {"User-Agent",
     "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"},
    {"Accept", "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8"},
    {"Accept-Language", "zh-CN,zh-TW;q=0.9,zh;q=0.8,en-US;q=0.7,en;q=0.6"},
    {"Accept-Encoding", "gzip, deflate, br"},
    {"Connection", "keep-alive"}
  ]

  @tile_templates %{
    "OpenStreetMap" => "https://{s}.tile.osm.org/{z}/{x}/{y}.png",
    # https://www.google.cn/maps/vt?lyrs=m@189&hl=zh&gl=cn&z=11&x=1664&y=891
    "GoogleCN" => "https://www.google.cn/maps/vt?lyrs=m@189&hl=zh&gl=cn&z={z}&x={x}&y={y}",
    # https://maponline0.bdimg.com/tile/?qt=vtile&z=12&x=767&y=157&styles=pl&scaler=1
    "Baidu" =>
      "https://maponline{s}.bdimg.com/tile/?qt=vtile&z={z}&x={x}&y={y}&styles=pl&scaler=1",
    "Tencent" => "https://rt{s}.map.gtimg.com/tile?z={z}&x={x}&y={-y}&type=vector&styleid=3",
    # http://wprd01.is.autonavi.com/appmaptile?z=11&x=1668&y=891&lang=zh_cn&size=1&scl=1&style=7
    "Amap" =>
      "https://webrd0{s}.is.autonavi.com/appmaptile?z={z}&x={x}&y={y}&lang=zh_cn&size=1&scale=1&style=7"
  }

  @subdomains %{
    "Baidu" => ["0", "1", "2", "3"],
    "Tencent" => ["0", "1", "2", "3"],
    "Amap" => ["1", "2", "3", "4"],
    "OpenStreetMap" => ["a", "b", "c"]
  }

  # 高德地图和腾讯地图使用 GCJ02 坐标系
  @gcj02_sources ["Amap", "Tencent"]

  adapter Tesla.Adapter.Finch, name: TeslaMate.HTTP, receive_timeout: 30_000

  plug Tesla.Middleware.Logger, debug: true, log_level: &log_level/1

  def tile_image(z, x, y, client_headers \\ [], opts \\ %{})

  def tile_image(z, x, y, client_headers, opts)
      when is_integer(z) and is_integer(x) and is_integer(y) do
    headers = if Enum.empty?(client_headers), do: @default_headers, else: client_headers

    url = get_tile_url(z, x, y, opts)

    Logger.debug("Getting tile image for z=#{z}, x=#{x}, y=#{y}, with opts=#{inspect(opts)}")
    Logger.debug("Tile URL: #{url}")

    case get(url, headers: headers) do
      {:ok, %Tesla.Env{status: 200, body: body, headers: response_headers}} ->
        {:ok, body, response_headers}

      _ ->
        {:error, :not_found}
    end
  end

  def tile_image(_, _, _, _, _), do: {:error, :invalid_coordinates}

  defp get_tile_url(z, x, y, opts) do
    tile_source = get_tile_source(opts)

    # 根据地图提供商进行坐标转换
    {converted_z, converted_x, converted_y} = convert_coordinates(tile_source, z, x, y)

    # 获取瓦片 URL 模板
    tile_template = get_tile_template(tile_source)

    # 构建 URL（包含瓦片坐标调整）
    build_tile_url(tile_template, tile_source, converted_z, converted_x, converted_y)
  end

  defp convert_coordinates(tile_source, z, x, y) do
    cond do
      tile_source == "Baidu" ->
        # 百度地图使用 BD09 坐标系
        CoordinateConverter.wgs_tile_to_bd_tile(z, x, y)

      tile_source in @gcj02_sources ->
        CoordinateConverter.wgs_tile_to_gcj_tile(z, x, y)

      true ->
        # 其他地图默认使用 WGS84 坐标系
        {z, x, y}
    end
  end

  defp get_tile_template(tile_source) do
    Map.get(@tile_templates, tile_source, "https://tile.openstreetmap.org/{z}/{x}/{y}.png")
  end

  defp build_tile_url(tile_template, tile_source, z, x, y) do
    # 应用瓦片坐标调整（Y轴翻转）
    adjusted_y = if tile_source in ["Baidu", "Tencent"], do: tms_convert_y(z, y), else: y

    replacements = %{
      z: z,
      x: x,
      y: adjusted_y,
      "-y": adjusted_y,
      s: get_subdomain(tile_source),
      sx: div(x, 16),
      sy: div(adjusted_y, 16)
    }

    # 执行替换
    Enum.reduce(replacements, tile_template, fn {pattern, value}, acc ->
      String.replace(acc, "{#{pattern}}", to_string(value))
    end)
  end

  defp tms_convert_y(z, y) do
    max_tile = trunc(:math.pow(2, z)) - 1
    max_tile - y
  end

  defp get_subdomain(tile_source) do
    case Map.get(@subdomains, tile_source) do
      nil -> ""
      subdomains -> Enum.random(subdomains)
    end
  end

  defp get_tile_source(opts) do
    case Map.get(opts, :tile_source) do
      source when is_binary(source) and source != "" -> source
      _ -> System.get_env("MAP_TILE_SOURCE", "OpenStreetMap")
    end
  end

  defp log_level(%Tesla.Env{} = env) when env.status >= 400, do: :warning
  defp log_level(%Tesla.Env{}), do: :info
end
