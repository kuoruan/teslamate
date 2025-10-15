defmodule TeslaMate.Locations.AmapApi do
  use Tesla, only: [:get]

  @version Mix.Project.config()[:version]

  adapter Tesla.Adapter.Finch, name: TeslaMate.HTTP, receive_timeout: 30_000

  plug Tesla.Middleware.BaseUrl, "https://restapi.amap.com"
  plug Tesla.Middleware.Headers, [{"user-agent", "TeslaMate/#{@version}"}]
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Logger, debug: true, log_level: &log_level/1

  alias TeslaMate.Locations.CoordConverter

  @doc """
  使用高德地图 API 进行逆地理编码查询。
  返回符合 OSM 格式的地址结构。
  """
  def reverse_lookup(lat, lon, lang, %{key: key, sig: sig}) do
    wgs_coord = CoordConverter.normalize(lat, lon)

    if wgs_coord == nil do
      {:error, {:invalid_coordinates, reason: "Coordinates invalid or out of range"}}
    else
      do_reverse_lookup(wgs_coord, lang, key, sig)
    end
  end

  defp do_reverse_lookup(wgs_coord, lang, key, sig) do
    # 高德地图使用 GCJ-02 坐标系，不支持 WGS-84 直接查询
    gcj_coord = CoordConverter.wgs_to_gcj(wgs_coord)

    params = [
      key: key,
      location: "#{gcj_coord.lon},#{gcj_coord.lat}",
      output: :json,
      extensions: :all,
      radius: 500,
      roadlevel: 0,
      sig: sig
    ]

    with {:ok, address_raw} <- query("/v3/geocode/regeo", lang, params),
         {:ok, address} <-
           into_address_amap(address_raw, %{origin: wgs_coord, location: gcj_coord}) do
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

  # 高德地图默认值
  @amap_defaults %{
    unknown_address: "未知地址",
    unknown_street: "未知街道",
    unknown_neighborhood: "未知社区",
    unknown_city: "未知城市",
    unknown_district: "未知区县",
    unknown_province: "未知省份",
    unknown_area: "未命名区域",
    default_country: "中国"
  }

  defp into_address_amap(%{"status" => "1", "regeocode" => result}, %{
         origin: wgs_coord,
         location: gcj_coord
       }) do
    formatted_address = Map.get(result, "formatted_address")
    address_component = Map.get(result, "addressComponent", %{})

    # 安全获取第一个POI
    poi = get_in(result, ["pois", Access.at(0)]) || %{}

    poi_name = Map.get(poi, "name")
    poi_business = Map.get(poi, "businessarea")

    # 显示名称优先级：格式化地址 > POI名称 > 默认值
    display_name =
      formatted_address ||
        poi_name ||
        @amap_defaults.unknown_address

    business_areas = Map.get(address_component, "businessAreas")
    business = get_in(business_areas, [Access.at(0), :name])

    street_number = Map.get(address_component, "streetNumber", %{})
    neighborhood = Map.get(address_component, "neighborhood", [])

    # 名称字段优先级：POI 名称 > 商圈名称 > 默认值
    name = poi_name || poi_business || business || @amap_defaults.unknown_area

    province = Map.get(address_component, "province")
    district = Map.get(address_component, "district")
    citycode = Map.get(address_component, "citycode")

    city =
      case Map.get(address_component, "city") do
        city when is_list(city) and length(city) > 0 -> List.first(city)
        city when is_binary(city) -> city
        _ -> if is_municipality?(citycode), do: province, else: district
      end

    # 格式化坐标，保留6位小数
    formatted_wgs_coord = CoordConverter.format(wgs_coord, 6)
    formatted_gcj_coord = CoordConverter.format(gcj_coord, 6)

    # 构造 OSM 地址结构
    address = %{
      display_name: display_name,
      osm_id: CoordConverter.hash(formatted_wgs_coord),
      osm_type: "node",
      latitude: formatted_wgs_coord.lat,
      longitude: formatted_wgs_coord.lon,
      name: name,
      house_number: Map.get(street_number, "number"),
      road: Map.get(street_number, "street") || @amap_defaults.unknown_street,
      neighbourhood:
        get_in(neighborhood, ["name", Access.at(0)]) || Map.get(address_component, "township") ||
          @amap_defaults.unknown_neighborhood,
      city: city || @amap_defaults.unknown_city,
      county: district || @amap_defaults.unknown_district,
      postcode: nil,
      state: Map.get(address_component, "province") || @amap_defaults.unknown_province,
      state_district: nil,
      country: Map.get(address_component, "country") || @amap_defaults.default_country,
      raw: %{
        "source" => "Amap",
        "formatted_address" => formatted_address,
        "pois" => [poi],
        "location" => formatted_gcj_coord,
        "origin_location" => wgs_coord,
        "addressComponent" => address_component
      }
    }

    {:ok, address}
  end

  defp into_address_amap(%{"info" => reason}, _coords) do
    {:error, {:amap_api_failure, reason}}
  end

  defp into_address_amap(_unexpected, _coords) do
    {:error, {:invalid_response_format, reason: "Unexpected response"}}
  end

  # 是否是直辖市
  defp is_municipality?(citycode) when citycode in ["010", "021", "022", "023"], do: true
  defp is_municipality?(_), do: false

  defp log_level(%Tesla.Env{} = env) when env.status >= 400, do: :warning
  defp log_level(%Tesla.Env{}), do: :info
end
