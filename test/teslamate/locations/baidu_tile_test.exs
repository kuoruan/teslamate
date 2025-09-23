defmodule TeslaMate.Locations.BaiduTileTest do
  use ExUnit.Case, async: true

  alias TeslaMate.Locations.CoordinateConverter

  describe "baidu tile coordinate conversion" do
    test "converts beijing coordinates correctly" do
      # 北京天安门的坐标 (WGS84)
      lat = 39.9042
      lon = 116.4074
      zoom = 12

      # 转换为百度瓦片坐标
      {z, x, y} = CoordinateConverter.baidu_coord_to_tile(lat, lon, zoom)

      assert z == zoom
      assert is_integer(x)
      assert is_integer(y)
      assert x > 0
      assert y > 0

      # 验证瓦片坐标在合理范围内
      max_tile = trunc(:math.pow(2, zoom))
      assert x < max_tile
      assert y < max_tile
    end

    test "wgs_tile_to_bd_tile conversion produces different coordinates" do
      # 使用标准的 WGS84 瓦片坐标
      wgs_z = 12
      wgs_x = 3364
      wgs_y = 1824

      # 转换为百度瓦片坐标
      {bd_z, bd_x, bd_y} = CoordinateConverter.wgs_tile_to_bd_tile(wgs_z, wgs_x, wgs_y)

      assert bd_z == wgs_z
      # 百度坐标应该与 WGS84 坐标不同
      assert bd_x != wgs_x or bd_y != wgs_y
    end

    test "baidu coordinate conversion is consistent" do
      lat = 39.9042
      lon = 116.4074
      zoom = 15

      # 多次转换应该得到相同结果
      {z1, x1, y1} = CoordinateConverter.baidu_coord_to_tile(lat, lon, zoom)
      {z2, x2, y2} = CoordinateConverter.baidu_coord_to_tile(lat, lon, zoom)

      assert {z1, x1, y1} == {z2, x2, y2}
    end
  end
end
