defmodule TeslaMate.Locations.CoordinateConverterTest do
  use ExUnit.Case, async: true

  alias TeslaMate.Locations.CoordinateConverter

  # 测试用的坐标点
  @beijing_wgs %{lat: 39.9042, lon: 116.4074}
  @beijing_gcj %{lat: 39.9100, lon: 116.4135}
  @beijing_bd %{lat: 39.9165, lon: 116.4200}

  @shanghai_wgs %{lat: 31.2304, lon: 121.4737}
  @shanghai_gcj %{lat: 31.2356, lon: 121.4806}

  # 旧金山
  @foreign_coord %{lat: 37.7749, lon: -122.4194}
  # 允许的误差范围（经纬度）
  @tolerance 0.01

  describe "distance/2" do
    test "calculates zero distance for same coordinates" do
      assert CoordinateConverter.distance(@beijing_wgs, @beijing_wgs) == 0.0
    end

    test "calculates distance between Beijing and Shanghai" do
      distance = CoordinateConverter.distance(@beijing_wgs, @shanghai_wgs)
      # Beijing to Shanghai is approximately 1066 km
      assert_in_delta distance, 1_066_000, 100_000
    end

    test "calculates short distance accurately" do
      coord1 = %{lat: 39.9042, lon: 116.4074}
      coord2 = %{lat: 39.9043, lon: 116.4075}
      distance = CoordinateConverter.distance(coord1, coord2)
      # Should be approximately 14 meters
      assert_in_delta distance, 14.0, 5.0
    end
  end

  describe "sanity_in_china?/1" do
    test "Beijing coordinates should be in China" do
      assert CoordinateConverter.sanity_in_china?(@beijing_wgs) == true
    end

    test "Shanghai coordinates should be in China" do
      assert CoordinateConverter.sanity_in_china?(@shanghai_wgs) == true
    end

    test "foreign coordinates should not be in China" do
      assert CoordinateConverter.sanity_in_china?(@foreign_coord) == false
    end

    test "boundary value testing" do
      # Test coordinates near China's borders
      china_south = %{lat: 1.0, lon: 110.0}
      china_north = %{lat: 55.0, lon: 110.0}
      china_west = %{lat: 35.0, lon: 73.0}
      china_east = %{lat: 35.0, lon: 137.0}

      assert CoordinateConverter.sanity_in_china?(china_south) == true
      assert CoordinateConverter.sanity_in_china?(china_north) == true
      assert CoordinateConverter.sanity_in_china?(china_west) == true
      assert CoordinateConverter.sanity_in_china?(china_east) == true

      # Coordinates outside boundaries
      outside_south = %{lat: 0.5, lon: 110.0}
      outside_north = %{lat: 56.0, lon: 110.0}
      outside_west = %{lat: 35.0, lon: 71.0}
      outside_east = %{lat: 35.0, lon: 139.0}

      assert CoordinateConverter.sanity_in_china?(outside_south) == false
      assert CoordinateConverter.sanity_in_china?(outside_north) == false
      assert CoordinateConverter.sanity_in_china?(outside_west) == false
      assert CoordinateConverter.sanity_in_china?(outside_east) == false
    end
  end

  describe "wgs_to_gcj/2" do
    test "converts Beijing WGS84 coordinates to GCJ02" do
      result = CoordinateConverter.wgs_to_gcj(@beijing_wgs)
      assert_in_delta result.lat, @beijing_gcj.lat, @tolerance
      assert_in_delta result.lon, @beijing_gcj.lon, @tolerance
    end

    test "converts Shanghai WGS84 coordinates to GCJ02" do
      result = CoordinateConverter.wgs_to_gcj(@shanghai_wgs)
      assert_in_delta result.lat, @shanghai_gcj.lat, @tolerance
      assert_in_delta result.lon, @shanghai_gcj.lon, @tolerance
    end

    test "foreign coordinates should not be converted" do
      result = CoordinateConverter.wgs_to_gcj(@foreign_coord, true)
      assert result == @foreign_coord
    end

    test "force convert foreign coordinates (ignore boundary check)" do
      result = CoordinateConverter.wgs_to_gcj(@foreign_coord, false)
      assert result != @foreign_coord
    end
  end

  describe "gcj_to_wgs/2" do
    test "converts Beijing GCJ02 coordinates to WGS84" do
      result = CoordinateConverter.gcj_to_wgs(@beijing_gcj)
      assert_in_delta result.lat, @beijing_wgs.lat, @tolerance
      assert_in_delta result.lon, @beijing_wgs.lon, @tolerance
    end

    test "foreign coordinates should not be converted" do
      result = CoordinateConverter.gcj_to_wgs(@foreign_coord, true)
      assert result == @foreign_coord
    end

    test "WGS84 to GCJ02 and back to WGS84 should be close to original" do
      gcj = CoordinateConverter.wgs_to_gcj(@beijing_wgs)
      wgs_back = CoordinateConverter.gcj_to_wgs(gcj)

      assert_in_delta wgs_back.lat, @beijing_wgs.lat, @tolerance
      assert_in_delta wgs_back.lon, @beijing_wgs.lon, @tolerance
    end
  end

  describe "gcj_to_bd/1" do
    test "converts Beijing GCJ02 coordinates to BD09" do
      result = CoordinateConverter.gcj_to_bd(@beijing_gcj)
      assert_in_delta result.lat, @beijing_bd.lat, @tolerance
      assert_in_delta result.lon, @beijing_bd.lon, @tolerance
    end

    test "conversion should increase coordinate values (BD09 offset)" do
      result = CoordinateConverter.gcj_to_bd(@beijing_gcj)
      assert result.lat > @beijing_gcj.lat
      assert result.lon > @beijing_gcj.lon
    end
  end

  describe "bd_to_gcj/1" do
    test "converts Beijing BD09 coordinates to GCJ02" do
      result = CoordinateConverter.bd_to_gcj(@beijing_bd)
      assert_in_delta result.lat, @beijing_gcj.lat, @tolerance
      assert_in_delta result.lon, @beijing_gcj.lon, @tolerance
    end

    test "BD09 to GCJ02 and back to BD09 should be close to original" do
      gcj = CoordinateConverter.bd_to_gcj(@beijing_bd)
      bd_back = CoordinateConverter.gcj_to_bd(gcj)

      assert_in_delta bd_back.lat, @beijing_bd.lat, 0.001
      assert_in_delta bd_back.lon, @beijing_bd.lon, 0.001
    end
  end

  describe "bd_to_wgs/2" do
    test "converts Beijing BD09 coordinates to WGS84" do
      result = CoordinateConverter.bd_to_wgs(@beijing_bd)
      assert_in_delta result.lat, @beijing_wgs.lat, @tolerance
      assert_in_delta result.lon, @beijing_wgs.lon, @tolerance
    end

    test "foreign coordinates should not be converted" do
      result = CoordinateConverter.bd_to_wgs(@foreign_coord, true)
      # Should go through bd_to_gcj but return directly at gcj_to_wgs
      intermediate = CoordinateConverter.bd_to_gcj(@foreign_coord)
      assert result == intermediate
    end
  end

  describe "wgs_to_bd/2" do
    test "converts Beijing WGS84 coordinates to BD09" do
      result = CoordinateConverter.wgs_to_bd(@beijing_wgs)
      assert_in_delta result.lat, @beijing_bd.lat, @tolerance
      assert_in_delta result.lon, @beijing_bd.lon, @tolerance
    end

    test "foreign coordinates should not be converted" do
      result = CoordinateConverter.wgs_to_bd(@foreign_coord, true)
      # Should return directly at wgs_to_gcj, then go through gcj_to_bd
      gcj_result = CoordinateConverter.gcj_to_bd(@foreign_coord)
      assert result == gcj_result
    end
  end

  describe "precise conversion functions" do
    test "gcj_to_wgs_precise/2 should be more accurate than normal conversion" do
      precise_result = CoordinateConverter.gcj_to_wgs_precise(@beijing_gcj)
      normal_result = CoordinateConverter.gcj_to_wgs(@beijing_gcj)

      # Precise conversion should be closer to original WGS84 coordinates
      precise_distance = CoordinateConverter.distance(precise_result, @beijing_wgs)
      normal_distance = CoordinateConverter.distance(normal_result, @beijing_wgs)

      assert precise_distance <= normal_distance
    end

    test "bd_to_gcj_precise/1 should be more accurate than normal conversion" do
      precise_result = CoordinateConverter.bd_to_gcj_precise(@beijing_bd)
      normal_result = CoordinateConverter.bd_to_gcj(@beijing_bd)

      # Precise conversion should be closer to original GCJ02 coordinates
      precise_distance = CoordinateConverter.distance(precise_result, @beijing_gcj)
      normal_distance = CoordinateConverter.distance(normal_result, @beijing_gcj)

      assert precise_distance <= normal_distance
    end

    test "bd_to_wgs_precise/2 should be more accurate than normal conversion" do
      precise_result = CoordinateConverter.bd_to_wgs_precise(@beijing_bd)
      normal_result = CoordinateConverter.bd_to_wgs(@beijing_bd)

      # Precise conversion should be closer to original WGS84 coordinates
      precise_distance = CoordinateConverter.distance(precise_result, @beijing_wgs)
      normal_distance = CoordinateConverter.distance(normal_result, @beijing_wgs)

      assert precise_distance <= normal_distance
    end
  end

  describe "formatting and hash functions" do
    test "format/2 should correctly format coordinates" do
      result = CoordinateConverter.format({39.123456789, 116.987654321}, 3)
      assert result == {39.123, 116.988}
    end

    test "format/2 should default to 6 decimal places" do
      result = CoordinateConverter.format({39.123456789, 116.987654321})
      assert result == {39.123457, 116.987654}
    end

    test "hash/2 should generate same hash for same coordinates" do
      hash1 = CoordinateConverter.hash(39.1234, 116.5678)
      hash2 = CoordinateConverter.hash(39.1234, 116.5678)
      assert hash1 == hash2
    end

    test "hash/2 should generate different hash for different coordinates" do
      hash1 = CoordinateConverter.hash(39.1234, 116.5678)
      hash2 = CoordinateConverter.hash(39.1235, 116.5678)
      assert hash1 != hash2
    end
  end

  describe "coordinate system conversion integrity tests" do
    test "WGS84 -> GCJ02 -> BD09 -> GCJ02 -> WGS84 should be close to original" do
      # WGS84 -> GCJ02
      gcj = CoordinateConverter.wgs_to_gcj(@beijing_wgs)

      # GCJ02 -> BD09
      bd = CoordinateConverter.gcj_to_bd(gcj)

      # BD09 -> GCJ02
      gcj_back = CoordinateConverter.bd_to_gcj(bd)

      # GCJ02 -> WGS84
      wgs_back = CoordinateConverter.gcj_to_wgs(gcj_back)

      # Verify final result is close to original coordinates
      assert_in_delta wgs_back.lat, @beijing_wgs.lat, @tolerance
      assert_in_delta wgs_back.lon, @beijing_wgs.lon, @tolerance
    end

    test "precise conversion round-trip test" do
      # Use precise conversion for round-trip test
      gcj = CoordinateConverter.wgs_to_gcj(@beijing_wgs)
      wgs_back = CoordinateConverter.gcj_to_wgs_precise(gcj)

      # Precise conversion should be very close to original coordinates
      assert_in_delta wgs_back.lat, @beijing_wgs.lat, 0.001
      assert_in_delta wgs_back.lon, @beijing_wgs.lon, 0.001
    end
  end

  describe "boundary condition tests" do
    test "handle extreme coordinates" do
      # Test very small values
      tiny_coord = %{lat: 0.0001, lon: 0.0001}
      result = CoordinateConverter.wgs_to_gcj(tiny_coord, false)
      assert is_map(result)
      assert Map.has_key?(result, :lat)
      assert Map.has_key?(result, :lon)

      # Test large values
      large_coord = %{lat: 89.9999, lon: 179.9999}
      result = CoordinateConverter.wgs_to_gcj(large_coord, false)
      assert is_map(result)
      assert Map.has_key?(result, :lat)
      assert Map.has_key?(result, :lon)
    end

    test "handle negative coordinates" do
      negative_coord = %{lat: -30.0, lon: -120.0}
      result = CoordinateConverter.wgs_to_gcj(negative_coord, false)
      assert is_map(result)
      assert Map.has_key?(result, :lat)
      assert Map.has_key?(result, :lon)
    end
  end
end
