defmodule TeslaMate.Locations.BaiduMercatorTest do
  use ExUnit.Case
  alias TeslaMate.Locations.BaiduMercator

  describe "ll_to_mc/2" do
    test "converts Beijing coordinates (BD09 to BD09MC)" do
      # 北京天安门广场的百度坐标
      {x, y} = BaiduMercator.ll_to_mc(116.404, 39.915)

      assert {Float.round(x, 2), Float.round(y, 2)} == {12_958_175.0, 4_825_923.77}
    end

    test "converts Shanghai coordinates (BD09 to BD09MC)" do
      # 上海外滩的百度坐标
      {x, y} = BaiduMercator.ll_to_mc(121.499, 31.240)

      assert {Float.round(x, 2), Float.round(y, 2)} == {13_525_353.98, 3_641_593.36}
    end

    test "converts negative longitude coordinates" do
      # 负经度测试
      {x, y} = BaiduMercator.ll_to_mc(-120.0, 35.0)

      assert {Float.round(x, 2), Float.round(y, 2)} == {-13_358_484.24, 4_139_145.66}
    end

    test "converts negative latitude coordinates" do
      # 负纬度测试
      {x, y} = BaiduMercator.ll_to_mc(120.0, -35.0)

      assert {Float.round(x, 2), Float.round(y, 2)} == {13_358_484.24, -4_139_145.66}
    end

    test "converts zero coordinates" do
      {x, y} = BaiduMercator.ll_to_mc(0.0, 0.0)

      assert {Float.round(x, 2), Float.round(y, 2)} == {0.0, 0.0}
    end
  end

  describe "mc_to_ll/2" do
    test "converts Beijing Mercator coordinates (BD09MC to BD09)" do
      # 使用北京天安门的墨卡托坐标
      {lon, lat} = BaiduMercator.mc_to_ll(12_958_224.0, 4_825_923.0)

      assert {Float.round(lon, 5), Float.round(lat, 5)} == {116.40444, 39.91499}
    end

    test "converts Shanghai Mercator coordinates (BD09MC to BD09)" do
      # 使用上海外滩的墨卡托坐标
      {lon, lat} = BaiduMercator.mc_to_ll(13_529_134.0, 3_661_910.0)

      assert {Float.round(lon, 5), Float.round(lat, 5)} == {121.53296, 31.39669}
    end

    test "converts negative Mercator coordinates" do
      # 负坐标测试
      {lon, lat} = BaiduMercator.mc_to_ll(-13_000_000.0, -4_000_000.0)

      assert {Float.round(lon, 5), Float.round(lat, 5)} == {-116.77972, -33.96492}
    end

    test "converts zero Mercator coordinates" do
      {lon, lat} = BaiduMercator.mc_to_ll(0.0, 0.0)

      assert {Float.round(lon, 5), Float.round(lat, 5)} == {0.0, 0.0}
    end
  end

  describe "round-trip coordinate conversion tests" do
    test "BD09 to BD09MC back to BD09 should maintain precision" do
      original_lon = 116.404
      original_lat = 39.915

      # BD09 -> BD09MC -> BD09
      {x, y} = BaiduMercator.ll_to_mc(original_lon, original_lat)
      {converted_lon, converted_lat} = BaiduMercator.mc_to_ll(x, y)

      # 验证往返转换的精度（允许小的浮点误差）
      assert abs(converted_lon - original_lon) < 0.0001
      assert abs(converted_lat - original_lat) < 0.0001
    end

    test "BD09MC to BD09 back to BD09MC should maintain precision" do
      original_x = 12_958_224.0
      original_y = 4_825_923.0

      # BD09MC -> BD09 -> BD09MC
      {lon, lat} = BaiduMercator.mc_to_ll(original_x, original_y)
      {converted_x, converted_y} = BaiduMercator.ll_to_mc(lon, lat)

      # 验证往返转换的精度（允许小的浮点误差）
      assert abs(converted_x - original_x) < 0.1
      assert abs(converted_y - original_y) < 0.1
    end

    test "round-trip conversion test for coordinates in different latitude zones" do
      test_coordinates = [
        # 北京 - 高纬度
        {116.404, 39.915},
        # 上海 - 中纬度
        {121.499, 31.240},
        # 广州 - 低纬度
        {113.264, 23.130},
        # 乌鲁木齐 - 西部高纬度
        {87.617, 43.828},
        # 哈尔滨 - 东北高纬度
        {126.642, 45.756}
      ]

      for {lon, lat} <- test_coordinates do
        {x, y} = BaiduMercator.ll_to_mc(lon, lat)
        {converted_lon, converted_lat} = BaiduMercator.mc_to_ll(x, y)

        assert abs(converted_lon - lon) < 0.0001,
               "Round-trip conversion longitude error: original=#{lon}, converted=#{converted_lon}"

        assert abs(converted_lat - lat) < 0.0001,
               "Round-trip conversion latitude error: original=#{lat}, converted=#{converted_lat}"
      end
    end
  end

  describe "boundary value tests" do
    test "maximum coordinate values" do
      # 测试极大的坐标值
      {x, y} = BaiduMercator.ll_to_mc(180.0, 74.0)
      assert {Float.round(x, 2), Float.round(y, 2)} == {20_037_726.37, 12_474_104.17}

      {lon, lat} = BaiduMercator.mc_to_ll(x, y)
      assert {Float.round(lon, 1), Float.round(lat, 1)} == {180.0, 74.0}
    end

    test "minimum coordinate values" do
      # 测试极小的坐标值
      {x, y} = BaiduMercator.ll_to_mc(-180.0, -74.0)
      assert {Float.round(x, 2), Float.round(y, 2)} == {-20_037_726.37, -12_474_104.17}

      {lon, lat} = BaiduMercator.mc_to_ll(x, y)
      assert {Float.round(lon, 1), Float.round(lat, 1)} == {-180.0, -74.0}
    end
  end
end
