defmodule TeslaMate.Maps.TileConverterTest do
  use TeslaMate.DataCase

  alias TeslaMate.Maps.TileConverter
  alias TeslaMate.Locations.CoordConverter

  describe "Coordinate to Tile conversion" do
    test "WGS to Tile" do
      {z, x, y} = TileConverter.coord_to_tile(15, %{lon: 116.39122, lat: 39.907354})
      assert {z, x, y} == {15, 26978, 12416}

      # https://tile.openstreetmap.org/15/26978/12416.png
    end

    test "GCJ to Tile" do
      gcj_coord = CoordConverter.wgs_to_gcj(%{lat: 39.907354, lon: 116.39122})

      assert {gcj_coord.lat, gcj_coord.lon} == {39.90875523135851, 116.3974611209652}

      {z, x, y} = TileConverter.coord_to_tile(15, gcj_coord)
      assert {z, x, y} == {15, 26978, 12416}

      # https://wprd01.is.autonavi.com/appmaptile?z=15&x=26978&y=12416&lang=zh_cn&size=1&scl=1&style=7
      # https://mt0.google.com/maps/vt/lyrs=m&hl=zh&gl=cn&z=15&x=26978&y=12416
    end

    test "Tencent coordinate to Tile" do
      tencent_coord = CoordConverter.wgs_to_gcj(%{lat: 39.907354, lon: 116.39122})

      assert {tencent_coord.lat, tencent_coord.lon} == {39.90875523135851, 116.3974611209652}

      {z, x, y} = TileConverter.coord_to_tile(15, tencent_coord)

      tms_y = TileConverter.tms_convert_y(z, y)

      assert {z, x, tms_y} == {15, 26978, 20351}
      # https://rt0.map.gtimg.com/tile?z=15&x=26978&y=20351&type=vector&styleid=1
    end
  end

  describe "baidu tile coordinate conversion" do
    test "baidu coordinate conversion is right" do
      {z1, x1, y1} = TileConverter.baidu_coord_to_tile(18, %{lon: 116.404, lat: 39.915})
      {z2, x2, y2} = TileConverter.baidu_coord_to_tile(11, %{lon: 106.557, lat: 29.570})

      assert {z1, x1, y1} == {18, 50617, 18851}
      assert {z2, x2, y2} == {11, 361, 104}
    end

    test "baidu_coord_to_tile with zoom 10" do
      {z, x, y} = TileConverter.baidu_coord_to_tile(10, %{lon: 116.404, lat: 39.915})

      assert {z, x, y} == {10, 197, 73}
    end

    test "baidu_tile_to_coord round trip" do
      zoom = 18
      tile_x = 50617
      tile_y = 18851

      coord = TileConverter.baidu_tile_to_coord(zoom, tile_x, tile_y)
      {z_back, x_back, y_back} = TileConverter.baidu_coord_to_tile(zoom, coord)

      assert z_back == zoom
      # Allow small error due to flooring
      assert abs(x_back - tile_x) <= 1
      assert abs(y_back - tile_y) <= 1
    end
  end

  describe "WGS to GCJ conversion" do
    test "wgs_to_gcj round trip approximation" do
      zoom = 10
      x = 512
      y = 341

      {z_gcj, x_gcj, y_gcj} = TileConverter.wgs_to_gcj(zoom, x, y)
      {z_wgs, x_wgs, y_wgs} = TileConverter.gcj_to_wgs(z_gcj, x_gcj, y_gcj)

      assert z_wgs == zoom
      # Allow small error due to coordinate transformation
      assert abs(x_wgs - x) <= 1
      assert abs(y_wgs - y) <= 1
    end

    test "wgs_to_gcj with zoom 0" do
      {z, x, y} = TileConverter.wgs_to_gcj(0, 0, 0)

      assert {z, x, y} == {0, 0, 0}
    end
  end

  describe "WGS to BD conversion" do
    test "wgs_to_bd round trip approximation" do
      zoom = 10
      x = 512
      y = 341

      {z_bd, x_bd, y_bd} = TileConverter.wgs_to_bd(zoom, x, y)
      {z_wgs, x_wgs, y_wgs} = TileConverter.bd_to_wgs(z_bd, x_bd, y_bd)

      assert z_wgs == zoom
      assert abs(x_wgs - x) <= 1
      assert abs(y_wgs - y) <= 1
    end
  end

  describe "GCJ to WGS conversion" do
    test "gcj_to_wgs basic conversion" do
      zoom = 10
      x = 512
      y = 341

      {z_wgs, x_wgs, y_wgs} = TileConverter.gcj_to_wgs(zoom, x, y)

      assert {z_wgs, x_wgs, y_wgs} == {10, 512, 341}
    end
  end

  describe "BD to WGS conversion" do
    test "bd_to_wgs basic conversion" do
      zoom = 10
      x = 512
      y = 341

      {z_wgs, x_wgs, y_wgs} = TileConverter.bd_to_wgs(zoom, x, y)

      assert {z_wgs, x_wgs, y_wgs} == {10, 1369, -61}
    end

    test "bd_to_wgs with zoom 0" do
      {z, x, y} = TileConverter.bd_to_wgs(0, 0, 0)

      assert {z, x, y} == {0, 0, 0}
    end
  end
end
