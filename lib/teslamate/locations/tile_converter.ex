defmodule TeslaMate.Locations.TileConverter do
  @moduledoc """
  瓦片坐标转换工具

  支持 WGS84、GCJ02、BD09 之间的相互转换
  """

  alias TeslaMate.Locations.BaiduMercator

  @pi :math.pi()

  # 瓦片大小（像素）
  @tile_size 256

  # 百度地图投影中的基准级别
  @bd_zoom_level 18

  @type coordinate :: %{lat: float(), lon: float()}

  @doc """
  将 WGS-84 坐标的瓦片坐标 (zoom, x, y) 转换为 GCJ-02 坐标系下的瓦片坐标
  """
  @spec wgs_to_gcj(integer(), integer(), integer()) :: {integer(), integer(), integer()}
  def wgs_to_gcj(zoom, x, y) do
    # GCJ-02 的瓦片坐标和 WGS-84 的瓦片坐标是相同的
    {zoom, x, y}
  end

  @doc """
  将 WGS-84 坐标的瓦片坐标 (zoom, x, y) 转换为 BD09 坐标系下的瓦片坐标
  百度地图使用特殊的瓦片坐标系统，需要特殊处理
  """
  @spec wgs_to_bd(integer(), integer(), integer()) :: {integer(), integer(), integer()}
  def wgs_to_bd(zoom, x, y) do
    coord = tile_to_coord(zoom, x, y)

    baidu_coord_to_tile(zoom, coord)
  end

  @doc """
  将 BD09 坐标转换为百度地图的瓦片坐标
  """
  @spec baidu_coord_to_tile(integer(), coordinate()) :: {integer(), integer(), integer()}
  def baidu_coord_to_tile(zoom, %{lon: lon, lat: lat}) do
    # 将 BD09 坐标转换为 BD09MC（百度墨卡托）坐标
    {mercator_x, mercator_y} = BaiduMercator.ll_to_mc(lon, lat)

    # 缩放因子：百度 API 瓦片计算的内部逻辑
    # 这里的 18 是百度地图投影中的一个关键基准级别
    resolution = :math.pow(2, zoom - @bd_zoom_level)

    # 百度墨卡托坐标 -> 瓦片坐标
    tile_x = floor(mercator_x * resolution / @tile_size)
    tile_y = floor(mercator_y * resolution / @tile_size)

    {zoom, tile_x, tile_y}
  end

  @doc """
  将百度地图瓦片坐标转换为 BD09 坐标
  """
  @spec baidu_tile_to_coord(integer(), integer(), integer()) :: coordinate()
  def baidu_tile_to_coord(zoom, tile_x, tile_y) do
    resolution = :math.pow(2, zoom - @bd_zoom_level)

    # 2. 像素坐标 -> 百度墨卡托坐标
    mercator_x = tile_x * @tile_size / resolution
    mercator_y = tile_y * @tile_size / resolution

    # 3. 百度墨卡托坐标 -> BD09 坐标
    {lon, lat} = BaiduMercator.mc_to_ll(mercator_x, mercator_y)

    %{lat: lat, lon: lon}
  end

  @doc """
  将 GCJ02 坐标的瓦片坐标 (zoom, x, y) 转换为 WGS84 坐标系下的瓦片坐标
  """
  @spec gcj_to_wgs(integer(), integer(), integer()) :: {integer(), integer(), integer()}
  def gcj_to_wgs(zoom, x, y) do
    # GCJ-02 的瓦片坐标和 WGS-84 的瓦片坐标是相同的
    {zoom, x, y}
  end

  @doc """
  将百度地图瓦片坐标 (zoom, x, y) 转换为 WGS84 坐标系下的瓦片坐标
  """
  @spec bd_to_wgs(integer(), integer(), integer()) :: {integer(), integer(), integer()}
  def bd_to_wgs(zoom, x, y) do
    coord = baidu_tile_to_coord(zoom, x, y)

    coord_to_tile(zoom, coord)
  end

  @doc """
  将经纬度坐标转换为瓦片坐标 (Web Mercator 投影)
  """
  @spec coord_to_tile(integer(), coordinate()) :: {integer(), integer(), integer()}
  def coord_to_tile(zoom, %{lon: lon, lat: lat}) do
    lat_rad = lat * @pi / 180
    n = :math.pow(2, zoom)

    x = floor((lon + 180) / 360 * n)
    y = floor((1 - :math.asinh(:math.tan(lat_rad)) / @pi) / 2 * n)

    {zoom, x, y}
  end

  @doc """
  将瓦片坐标转换为经纬度坐标 (Web Mercator 投影)
  """
  @spec tile_to_coord(integer(), integer(), integer()) :: coordinate()
  def tile_to_coord(zoom, x, y) do
    n = :math.pow(2, zoom)

    lon = x / n * 360 - 180
    lat_rad = :math.atan(:math.sinh(@pi * (1 - 2 * y / n)))
    lat = lat_rad * 180 / @pi

    %{lat: lat, lon: lon}
  end

  @doc """
  将瓦片坐标转换为瓦片边界框的经纬度坐标
  """
  @spec tile_to_bbox(integer(), integer(), integer()) :: {float(), float(), float(), float()}
  def tile_to_bbox(zoom, x, y) do
    %{lat: south, lon: west} = tile_to_coord(zoom, x, y)
    %{lat: north, lon: east} = tile_to_coord(zoom, x + 1, y + 1)

    {west, south, east, north}
  end

  @doc """
  将标准瓦片 y 坐标转换为 TMS 坐标
  适用于某些使用 TMS 坐标系统的地图提供商
  """
  @spec tms_convert_y(integer(), integer()) :: integer()
  def tms_convert_y(z, y) do
    max_tile = trunc(:math.pow(2, z)) - 1
    max_tile - y
  end
end
