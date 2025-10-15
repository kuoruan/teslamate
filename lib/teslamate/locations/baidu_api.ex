defmodule TeslaMate.Locations.BaiduApi do
  use Tesla, only: [:get]

  @version Mix.Project.config()[:version]

  adapter Tesla.Adapter.Finch, name: TeslaMate.HTTP, receive_timeout: 30_000

  plug Tesla.Middleware.BaseUrl, "https://api.map.baidu.com"
  plug Tesla.Middleware.Headers, [{"user-agent", "TeslaMate/#{@version}"}]
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Logger, debug: true, log_level: &log_level/1

  alias TeslaMate.Locations.CoordConverter

  @doc """
  使用百度地图 API 进行逆地理编码查询。
  返回符合 OSM 格式的地址结构。
  """
  def reverse_lookup(lat, lon, lang, %{ak: ak, sk: sk}) do
    wgs_coord = CoordConverter.normalize(lat, lon)

    if wgs_coord == nil do
      {:error, {:invalid_coordinates, reason: "Coordinates invalid or out of range"}}
    else
      do_reverse_lookup(wgs_coord, lang, ak, sk)
    end
  end

  defp do_reverse_lookup(wgs_coord, lang, ak, sk) do
    base_params = [
      ak: ak,
      coordtype: :wgs84ll,
      extensions_poi: 1,
      # 返回国测局坐标
      ret_coordtype: :gcj02ll,
      location: "#{wgs_coord.lat},#{wgs_coord.lon}",
      output: :json
    ]

    query_str =
      base_params
      |> Enum.map(fn {k, v} -> "#{k}=#{URI.encode_www_form(to_string(v))}" end)
      |> Enum.join("&")

    uri_path = "/reverse_geocoding/v3"

    raw_for_sign = "#{uri_path}?#{query_str}#{sk}"
    encoded_for_sign = URI.encode_www_form(raw_for_sign)
    sn = :crypto.hash(:md5, encoded_for_sign) |> Base.encode16(case: :lower)

    params = base_params ++ [sn: sn]

    with {:ok, address_raw} <- query(uri_path, lang, params),
         {:ok, address} <- into_address_baidu(address_raw, %{origin: wgs_coord}) do
      {:ok, address}
    end
  end

  defp query(url, lang, params) do
    case get(url,
           query: params,
           headers: [{"Accept-Language", lang}, {"Accept", "application/json"}]
         ) do
      {:ok, %Tesla.Env{status: 200, body: body}} -> {:ok, body}
      {:ok, %Tesla.Env{} = env} -> {:error, reason: "Unexpected response", env: env}
      {:error, reason} -> {:error, reason}
    end
  end

  # 百度地图默认值
  @baidu_defaults %{
    unknown_address: "未知地址",
    unknown_street: "未知街道",
    unknown_village: "未知社区",
    unknown_city: "未知城市",
    unknown_district: "未知区县",
    unknown_province: "未知省份",
    unknown_area: "未命名区域",
    default_country: "中国"
  }

  defp into_address_baidu(%{"status" => 0, "result" => result}, %{origin: wgs_coord}) do
    lat = get_in(result, ["location", "lat"]) || 0.0
    lon = get_in(result, ["location", "lng"]) || 0.0

    formatted_address_poi = Map.get(result, "formatted_address_poi")
    formatted_address = Map.get(result, "formatted_address")
    address_component = Map.get(result, "addressComponent", %{})

    # 安全获取第一个POI
    poi = get_in(result, ["pois", Access.at(0)]) || %{}
    poi_name = Map.get(poi, "name")

    # 显示名称优先级：格式化地址 > POI名称 > 默认值
    display_name =
      formatted_address_poi ||
        formatted_address ||
        poi_name ||
        @baidu_defaults.unknown_address

    business = Map.get(result, "business")

    # 名称字段优先级：POI 名称 > 商圈名称 > 默认值
    name = poi_name || business || @baidu_defaults.unknown_area

    # 格式化坐标，保留6位小数
    formatted_wgs_coord = CoordConverter.format(wgs_coord, 6)

    # 构造 OSM 地址结构
    address = %{
      display_name: display_name,
      osm_id: CoordConverter.hash(formatted_wgs_coord),
      osm_type: "node",
      latitude: formatted_wgs_coord.lat,
      longitude: formatted_wgs_coord.lon,
      name: name,
      house_number: Map.get(address_component, "street_number"),
      road: Map.get(address_component, "street") || @baidu_defaults.unknown_street,
      neighbourhood:
        Map.get(address_component, "village") ||
          Map.get(address_component, "town") || @baidu_defaults.unknown_village,
      city: Map.get(address_component, "city") || @baidu_defaults.unknown_city,
      county: Map.get(address_component, "district") || @baidu_defaults.unknown_district,
      postcode: Map.get(poi, "zip"),
      state: Map.get(address_component, "province") || @baidu_defaults.unknown_province,
      state_district: nil,
      country: Map.get(address_component, "country") || @baidu_defaults.default_country,
      raw: %{
        "source" => "Baidu",
        "formatted_address_poi" => formatted_address_poi,
        "formatted_address" => formatted_address,
        "pois" => [poi],
        "business" => business,
        "location" => %{"lat" => lat, "lng" => lon},
        "origin_location" => wgs_coord,
        "addressComponent" => address_component
      }
    }

    {:ok, address}
  end

  defp into_address_baidu(%{"status" => code, "message" => reason}, _coords) do
    {:error, {:baidu_api_failure, code, reason}}
  end

  defp into_address_baidu(_unexpected, _coords) do
    {:error, {:invalid_response_format, reason: "Unexpected response"}}
  end

  defp log_level(%Tesla.Env{} = env) when env.status >= 400, do: :warning
  defp log_level(%Tesla.Env{}), do: :info
end
