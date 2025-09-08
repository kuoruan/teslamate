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

  # 百度的人工偏差
  @bd_dlat 0.0060
  @bd_dlon 0.0065

  # 地球平均半径
  @earth_r 6_371_000

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
end
