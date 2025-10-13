defmodule TeslaMate.Locations.Maps do
  @moduledoc """
  Provides map tile rendering functionality.

  https://github.com/htoooth/Leaflet.ChineseTmsProviders
  """

  use Tesla, only: [:get]

  require Logger

  alias TeslaMate.Locations.TileConverter

  adapter Tesla.Adapter.Finch, name: TeslaMate.HTTP, receive_timeout: 30_000

  plug Tesla.Middleware.FollowRedirects, max_redirects: 3
  plug Tesla.Middleware.Logger, debug: true, log_level: &log_level/1

  @default_headers [
    {"user-agent",
     "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"},
    {"accept", "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8"},
    {"accept-language", "zh-CN,zh-TW;q=0.9,zh;q=0.8,en-US;q=0.7,en;q=0.6"},
    {"accept-encoding", "gzip, deflate, br"}
  ]

  # 额外允许透传的缓存相关头部
  @cache_headers [
    "if-modified-since",
    "if-none-match",
    "cache-control",
    "pragma",
    "expires",
    "etag",
    "last-modified"
  ]

  @tile_templates %{
    # http://wprd01.is.autonavi.com/appmaptile?z=8&x=203&y=105&lang=zh_cn&size=1&scl=1&style=7
    "Amap" =>
      "https://webrd0{s}.is.autonavi.com/appmaptile?z={z}&x={x}&y={y}&lang=zh_cn&size=1&scale=1&style=7",
    # https://maponline0.bdimg.com/tile/?qt=vtile&z=8&x=44&y=13&styles=pl&scaler=1
    "Baidu" =>
      "https://maponline{s}.bdimg.com/tile/?qt=vtile&z={z}&x={x}&y={y}&styles=pl&scaler=1",
    # https://mt0.google.com/maps/vt/lyrs=m&hl=zh&gl=cn&z=8&x=203&y=105
    "Google" => "https://mt{s}.google.com/vt/?lyrs=m&hl=zh&gl=cn&z={z}&x={x}&y={y}",
    # https://a.tile.osm.org/8/203/105.png
    "OpenStreetMap" => "https://{s}.tile.osm.org/{z}/{x}/{y}.png",
    # https://rt0.map.gtimg.com/tile?z=8&x=203&y=150&type=vector&styleid=1
    "Tencent" => "https://rt{s}.map.gtimg.com/tile?z={z}&x={x}&y={-y}&type=vector&styleid=1"
  }

  @subdomains %{
    "Amap" => ["1", "2", "3", "4"],
    "Baidu" => ["0", "1", "2", "3"],
    "Google" => ["0", "1", "2", "3"],
    "OpenStreetMap" => ["a", "b", "c"],
    "Tencent" => ["0", "1", "2", "3"]
  }

  @default_tile_source "OpenStreetMap"

  # 使用 GCJ-02 坐标系的地图提供商
  @gcj02_sources ["Amap", "Google", "Tencent"]

  @doc """
  获取地图瓦片图像，透传上游服务的完整响应。

  ## 参数
  - z: 缩放级别
  - x: X 坐标
  - y: Y 坐标
  - client_headers: 客户端请求头部
  - opts: 选项，包含 tile_source 等

  ## 返回值
  - `{:ok, status, body, response_headers}` - 成功获取响应，包含状态码、响应体和响应头
  - `{:error, reason}` - 获取失败
  """
  def tile_image(zoom, x, y, client_headers \\ [], opts \\ %{})

  def tile_image(zoom, x, y, client_headers, opts)
      when is_integer(zoom) and is_integer(x) and is_integer(y) do
    headers = prepare_headers(client_headers)
    url = get_tile_url(zoom, x, y, opts)

    Logger.debug(
      "Getting tile image for zoom=#{zoom}, x=#{x}, y=#{y}, with opts=#{inspect(opts)}"
    )

    Logger.debug("Tile URL: #{url}")

    case get(url, headers: headers) do
      {:ok, %Tesla.Env{status: status, body: body, headers: response_headers}} ->
        {:ok, status, body, response_headers}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def tile_image(_, _, _, _, _), do: {:error, :invalid_coordinates}

  defp prepare_headers(client_headers) do
    if Enum.empty?(client_headers) do
      @default_headers
    else
      # 创建允许的头部名称集合
      allowed_header_names = create_allowed_headers_set()

      # 过滤客户端头部，只保留允许的头部
      filtered_client_headers =
        client_headers
        |> Enum.filter(fn {name, _} ->
          String.downcase(name) in allowed_header_names
        end)

      # 合并：客户端头部 + 缺失的默认头部
      merge_with_defaults(filtered_client_headers)
    end
  end

  # 创建允许的头部名称集合（默认头部 + 缓存头部）
  defp create_allowed_headers_set do
    default_names = Enum.map(@default_headers, fn {name, _} -> name end)
    MapSet.new(default_names ++ @cache_headers)
  end

  # 合并客户端头部和默认头部
  defp merge_with_defaults(client_headers) do
    if Enum.empty?(client_headers) do
      @default_headers
    else
      # 获取客户端已提供的头部名称
      client_header_names =
        client_headers
        |> Enum.map(fn {name, _} -> String.downcase(name) end)
        |> MapSet.new()

      # 找出缺失的默认头部
      missing_defaults =
        @default_headers
        |> Enum.reject(fn {name, _} -> name in client_header_names end)

      # 合并：客户端头部优先，补充缺失的默认头部
      client_headers ++ missing_defaults
    end
  end

  defp get_tile_url(zoom, x, y, opts) do
    tile_source = get_tile_source(opts)

    # 根据地图提供商进行坐标转换
    {converted_zoom, converted_x, converted_y} = convert_coordinates(tile_source, zoom, x, y)

    # 获取瓦片 URL 模板
    tile_template = Map.get(@tile_templates, tile_source)

    # 构建 URL（包含瓦片坐标调整）
    build_tile_url(tile_template, tile_source, converted_zoom, converted_x, converted_y)
  end

  defp convert_coordinates(tile_source, zoom, x, y) do
    cond do
      tile_source == "Baidu" ->
        # 百度地图使用 BD09 坐标系
        TileConverter.wgs_to_bd(zoom, x, y)

      tile_source in @gcj02_sources ->
        TileConverter.wgs_to_gcj(zoom, x, y)

      true ->
        # 其他地图默认使用 WGS84 坐标系
        {zoom, x, y}
    end
  end

  defp build_tile_url(tile_template, tile_source, zoom, x, y) do
    replacements = %{
      z: zoom,
      x: x,
      y: y,
      "-y": tms_convert_y(zoom, y),
      s: get_subdomain(tile_source)
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
    source =
      case Map.get(opts, "source") do
        source when is_binary(source) and source != "" -> source
        _ -> System.get_env("MAP_TILE_SOURCE", @default_tile_source)
      end

    if Map.has_key?(@tile_templates, source), do: source, else: @default_tile_source
  end

  defp log_level(%Tesla.Env{} = env) when env.status >= 400, do: :warning
  defp log_level(%Tesla.Env{}), do: :info
end
