defmodule TeslaMate.Locations.CoordinateConverter do
  @moduledoc """
  经纬度转换工具
  支持 WGS84、GCJ02、BD09 之间的相互转换

  基于 Artoria2e5 的 JavaScript 实现
  @see https://github.com/Artoria2e5/PRCoords
  """

  # Krasovsky 1940 椭球体常数
  @gcj_a 6_378_245
  @gcj_ee 0.00669342162296594323

  # "精确"迭代的误差值
  @prc_eps 1.0e-5

  # 地球平均半径
  @earth_r 6_371_000

  # 百度的人工偏差
  @bd_dlat 0.0060
  @bd_dlon 0.0065

  # 百度地图椭球体参数 (Krasovsky 1940)
  @baidu_a 6_378_206.0

  # 百度地图分辨率计算基础值
  @baidu_resolution_base 18

  # 百度地图最大范围
  @baidu_max_extent 20_037_508.342789244

  # 瓦片大小
  @tile_size 256

  @type coordinate :: %{lat: float(), lon: float()}

  @doc """
  使用 Haversine 方法计算两个坐标之间的距离。
  适用于短距离，如转换偏差检查。
  """
  @spec distance(coordinate(), coordinate()) :: float()
  def distance(%{lat: lat1} = a, %{lat: lat2} = b) do
    delta = coord_diff(a, b)

    lat1_rad = lat1 * :math.pi() / 180
    lat2_rad = lat2 * :math.pi() / 180
    delta_lat_rad = delta.lat * :math.pi() / 180
    delta_lon_rad = delta.lon * :math.pi() / 180

    a =
      haversine(delta_lat_rad) +
        :math.cos(lat1_rad) * :math.cos(lat2_rad) * haversine(delta_lon_rad)

    2 * @earth_r * :math.asin(:math.sqrt(a))
  end

  @doc """
  检查坐标是否在中国境内。
  """
  @spec sanity_in_china?(coordinate()) :: boolean()
  def sanity_in_china?(%{lat: lat, lon: lon}) do
    lat >= 0.8293 and lat <= 55.8271 and
      lon >= 72.004 and lon <= 137.8347
  end

  @doc """
  将 WGS-84 坐标转换为 GCJ-02。
  """
  @spec wgs_to_gcj(coordinate(), boolean()) :: coordinate()
  def wgs_to_gcj(wgs, check_china \\ true)

  def wgs_to_gcj(%{lat: lat, lon: lon} = wgs, check_china) do
    if check_china and not sanity_in_china?(wgs) do
      # 发现非中国坐标，直接返回
      wgs
    else
      x = lon - 105
      y = lat - 35

      {d_lat_m, d_lon_m} = calculate_distortions(x, y)

      rad_lat = lat / 180 * :math.pi()
      magic = 1 - @gcj_ee * :math.pow(:math.sin(rad_lat), 2)

      lat_deg_arclen = :math.pi() / 180 * (@gcj_a * (1 - @gcj_ee)) / :math.pow(magic, 1.5)
      lon_deg_arclen = :math.pi() / 180 * (@gcj_a * :math.cos(rad_lat) / :math.sqrt(magic))

      %{
        lat: lat + d_lat_m / lat_deg_arclen,
        lon: lon + d_lon_m / lon_deg_arclen
      }
    end
  end

  @doc """
  将 GCJ-02 坐标转换为 WGS-84（粗略近似）。
  """
  @spec gcj_to_wgs(coordinate(), boolean()) :: coordinate()
  def gcj_to_wgs(gcj, check_china \\ true) do
    diff = coord_diff(wgs_to_gcj(gcj, check_china), gcj)
    coord_diff(gcj, diff)
  end

  @doc """
  将 GCJ-02 坐标转换为 BD-09。
  """
  @spec gcj_to_bd(coordinate()) :: coordinate()
  def gcj_to_bd(%{lat: lat, lon: lon}) do
    x = lon
    y = lat

    r = :math.sqrt(x * x + y * y) + 0.00002 * :math.sin(y * :math.pi() * 3000 / 180)
    theta = :math.atan2(y, x) + 0.000003 * :math.cos(x * :math.pi() * 3000 / 180)

    %{
      lat: r * :math.sin(theta) + @bd_dlat,
      lon: r * :math.cos(theta) + @bd_dlon
    }
  end

  @doc """
  将 BD-09 坐标转换为 GCJ-02。
  """
  @spec bd_to_gcj(coordinate()) :: coordinate()
  def bd_to_gcj(%{lat: lat, lon: lon}) do
    x = lon - @bd_dlon
    y = lat - @bd_dlat

    r = :math.sqrt(x * x + y * y) - 0.00002 * :math.sin(y * :math.pi() * 3000 / 180)
    theta = :math.atan2(y, x) - 0.000003 * :math.cos(x * :math.pi() * 3000 / 180)

    %{
      lat: r * :math.sin(theta),
      lon: r * :math.cos(theta)
    }
  end

  @doc """
  将 BD-09 坐标转换为 WGS-84。
  """
  @spec bd_to_wgs(coordinate(), boolean()) :: coordinate()
  def bd_to_wgs(bd, check_china \\ true) do
    bd |> bd_to_gcj() |> gcj_to_wgs(check_china)
  end

  @doc """
  将 WGS-84 坐标转换为 BD-09。
  """
  @spec wgs_to_bd(coordinate(), boolean()) :: coordinate()
  def wgs_to_bd(wgs, check_china \\ true) do
    wgs |> wgs_to_gcj(check_china) |> gcj_to_bd()
  end

  @doc """
  使用迭代方法精确地将 GCJ-02 转换为 WGS-84。
  """
  @spec gcj_to_wgs_precise(coordinate(), boolean()) :: coordinate()
  def gcj_to_wgs_precise(gcj, check_china \\ true) do
    iterate_conversion(&wgs_to_gcj/2, &gcj_to_wgs/2, gcj, check_china)
  end

  @doc """
  使用迭代方法精确地将 BD-09 转换为 GCJ-02。
  """
  @spec bd_to_gcj_precise(coordinate()) :: coordinate()
  def bd_to_gcj_precise(bd) do
    iterate_conversion(&gcj_to_bd/1, &bd_to_gcj/1, bd, false)
  end

  @doc """
  使用迭代方法精确地将 BD-09 转换为 WGS-84。
  """
  @spec bd_to_wgs_precise(coordinate(), boolean()) :: coordinate()
  def bd_to_wgs_precise(bd, check_china \\ true) do
    iterate_conversion(&wgs_to_bd/2, &bd_to_wgs/2, bd, check_china)
  end

  # 私有函数

  # 半正矢函数
  defp haversine(theta) do
    :math.pow(:math.sin(theta / 2), 2)
  end

  # 计算坐标差值
  defp coord_diff(%{lat: lat1, lon: lon1}, %{lat: lat2, lon: lon2}) do
    %{lat: lat1 - lat2, lon: lon1 - lon2}
  end

  # 计算扭曲值
  # 这些扭曲函数接受 (x = lon - 105, y = lat - 35)
  # 它们返回以弧长为单位的扭曲值，单位为米
  defp calculate_distortions(x, y) do
    d_lat_m =
      -100 + 2 * x + 3 * y + 0.2 * y * y + 0.1 * x * y +
        0.2 * :math.sqrt(abs(x)) +
        (2 * :math.sin(x * 6 * :math.pi()) + 2 * :math.sin(x * 2 * :math.pi()) +
           2 * :math.sin(y * :math.pi()) + 4 * :math.sin(y / 3 * :math.pi()) +
           16 * :math.sin(y / 12 * :math.pi()) + 32 * :math.sin(y / 30 * :math.pi())) * 20 / 3

    d_lon_m =
      300 + x + 2 * y + 0.1 * x * x + 0.1 * x * y +
        0.1 * :math.sqrt(abs(x)) +
        (2 * :math.sin(x * 6 * :math.pi()) + 2 * :math.sin(x * 2 * :math.pi()) +
           2 * :math.sin(x * :math.pi()) + 4 * :math.sin(x / 3 * :math.pi()) +
           15 * :math.sin(x / 12 * :math.pi()) + 30 * :math.sin(x / 30 * :math.pi())) * 20 / 3

    {d_lat_m, d_lon_m}
  end

  # 迭代转换的通用函数，使用 Caijun 2014 方法
  # gcj: 调用 4 次 wgs_gcj; ~0.1mm 精度
  defp iterate_conversion(forward_func, reverse_func, target, check_china)
       when is_boolean(check_china) do
    curr =
      if check_china do
        reverse_func.(target, check_china)
      else
        reverse_func.(target)
      end

    iterate_conversion_loop(forward_func, target, curr, check_china, 0)
  end

  defp iterate_conversion(forward_func, reverse_func, target, _check_china) do
    curr = reverse_func.(target)
    iterate_conversion_loop(forward_func, target, curr, false, 0)
  end

  # 迭代转换循环，等到达到固定点或达到最大迭代次数
  defp iterate_conversion_loop(_forward_func, _target, curr, _check_china, 10), do: curr

  defp iterate_conversion_loop(forward_func, target, curr, check_china, iteration) do
    forward_result =
      if check_china do
        forward_func.(curr, check_china)
      else
        forward_func.(curr)
      end

    diff = coord_diff(forward_result, target)

    if max(abs(diff.lat), abs(diff.lon)) <= @prc_eps do
      curr
    else
      new_curr = coord_diff(curr, diff)
      iterate_conversion_loop(forward_func, target, new_curr, check_china, iteration + 1)
    end
  end

  @doc """
  格式化坐标输出（保留指定小数位）
  """
  def format({lat, lon}, precision \\ 6) do
    {Float.round(lat, precision), Float.round(lon, precision)}
  end

  @doc """
  生成坐标唯一标识符（哈希值）
  """
  def hash(lat, lon), do: :erlang.phash2({lat, lon}, 0xFFFFFFFF)

  # Tile坐标转换方法

  @doc """
  将 WGS-84 坐标的 tile 坐标 (z, x, y) 转换为 GCJ-02 坐标系下的 tile 坐标
  """
  @spec wgs_tile_to_gcj_tile(integer(), integer(), integer()) :: {integer(), integer(), integer()}
  def wgs_tile_to_gcj_tile(z, x, y) do
    wgs_coord = tile_to_coord(z, x, y)

    gcj_coord = wgs_to_gcj(wgs_coord)

    coord_to_tile(gcj_coord.lat, gcj_coord.lon, z)
  end

  @doc """
  将 WGS-84 坐标的 tile 坐标 (z, x, y) 转换为 BD09 坐标系下的 tile 坐标
  百度地图使用特殊的瓦片坐标系统，需要特殊处理
  """
  @spec wgs_tile_to_bd_tile(integer(), integer(), integer()) :: {integer(), integer(), integer()}
  def wgs_tile_to_bd_tile(z, x, y) do
    wgs_coord = tile_to_coord(z, x, y)

    bd_coord = wgs_to_bd(wgs_coord)

    baidu_coord_to_tile(bd_coord.lat, bd_coord.lon, z)
  end

  @doc """
  将 BD09 坐标转换为百度地图的瓦片坐标
  基于 leaflet-tileLayer-baidugaode 的百度地图 CRS 配置
  https://github.com/muyao1987/leaflet-tileLayer-baidugaode/blob/master/src/tileLayer.baidu.js
  """
  @spec baidu_coord_to_tile(float(), float(), integer()) :: {integer(), integer(), integer()}
  def baidu_coord_to_tile(lat, lon, zoom) do
    # 转换为墨卡托投影坐标
    lat_rad = lat * :math.pi() / 180
    lon_rad = lon * :math.pi() / 180

    # 百度地图的墨卡托投影
    x_merc = @baidu_a * lon_rad
    y_merc = @baidu_a * :math.log(:math.tan(:math.pi() / 4 + lat_rad / 2))

    # 百度地图的分辨率定义
    # res[0] = Math.pow(2, 18), res[i] = Math.pow(2, (18 - i))
    resolution = :math.pow(2, @baidu_resolution_base - zoom)

    # 计算像素坐标 (原点在左上角)
    pixel_x = (x_merc + @baidu_max_extent) / resolution
    pixel_y = (@baidu_max_extent - y_merc) / resolution

    # 计算瓦片坐标
    tile_x = trunc(pixel_x / @tile_size)
    tile_y = trunc(pixel_y / @tile_size)

    # 确保瓦片坐标在有效范围内
    max_tile = trunc(:math.pow(2, zoom))
    tile_x = max(0, min(tile_x, max_tile - 1))
    tile_y = max(0, min(tile_y, max_tile - 1))

    {zoom, tile_x, tile_y}
  end

  @doc """
  将 GCJ02 坐标的 tile 坐标 (z, x, y) 转换为 WGS84 坐标系下的 tile 坐标
  """
  @spec gcj_tile_to_wgs_tile(integer(), integer(), integer()) :: {integer(), integer(), integer()}
  def gcj_tile_to_wgs_tile(z, x, y) do
    gcj_coord = tile_to_coord(z, x, y)

    wgs_coord = gcj_to_wgs(gcj_coord)

    coord_to_tile(wgs_coord.lat, wgs_coord.lon, z)
  end

  @doc """
  将 BD09 坐标的 tile 坐标 (z, x, y) 转换为 WGS84 坐标系下的 tile 坐标
  """
  @spec bd_tile_to_wgs_tile(integer(), integer(), integer()) :: {integer(), integer(), integer()}
  def bd_tile_to_wgs_tile(z, x, y) do
    bd_coord = tile_to_coord(z, x, y)

    wgs_coord = bd_to_wgs(bd_coord)

    coord_to_tile(wgs_coord.lat, wgs_coord.lon, z)
  end

  @doc """
  将经纬度坐标转换为 tile 坐标 (Web Mercator 投影)
  """
  @spec coord_to_tile(float(), float(), integer()) :: {integer(), integer(), integer()}
  def coord_to_tile(lat, lon, zoom) do
    lat_rad = lat * :math.pi() / 180
    n = :math.pow(2, zoom)

    x = trunc((lon + 180) / 360 * n)
    y = trunc((1 - :math.asinh(:math.tan(lat_rad)) / :math.pi()) / 2 * n)

    {zoom, x, y}
  end

  @doc """
  将 tile 坐标转换为经纬度坐标 (Web Mercator 投影)
  """
  @spec tile_to_coord(integer(), integer(), integer()) :: coordinate()
  def tile_to_coord(zoom, x, y) do
    n = :math.pow(2, zoom)

    lon = x / n * 360 - 180
    lat_rad = :math.atan(:math.sinh(:math.pi() * (1 - 2 * y / n)))
    lat = lat_rad * 180 / :math.pi()

    %{lat: lat, lon: lon}
  end
end
