defmodule TeslaMate.Locations.BaiduMapTest do
  use ExUnit.Case, async: true

  alias TeslaMate.Locations.BaiduMap

  import Mock

  @tag :baidu
  test "test baidu reverse lookup" do
    with_mock Tesla.Adapter.Finch,
      call: fn %Tesla.Env{} = env, _opts ->
        # Assert the expected URL and params for Baidu API
        assert env.url == "https://api.map.baidu.com/reverse_geocoding/v3"

        # Ensure the query parameters are has the same order and values
        assert env.query == [
                 ak: "test",
                 coordtype: :wgs84ll,
                 extensions_poi: 1,
                 ret_coordtype: :gcj02ll,
                 location: "39.907333,116.391083",
                 output: :json,
                 sn: "4c21cb1cada2eec159e8ff088e31764b"
               ]

        # Add more assertions as needed for query params

        # Mock the response
        {:ok,
         %Tesla.Env{
           body: %{
             "status" => 0,
             "result" => %{
               "location" => %{"lat" => 39.90873911887158, "lng" => 116.39732983405372},
               "business" => "前门,王府井",
               "formatted_address_poi" => "北京市东城区东华门街道天安门",
               "formatted_address" => "北京市东城区东华门街道中华路甲10号",
               "addressComponent" => %{
                 "country" => "中国",
                 "country_code" => 0,
                 "country_code_iso" => "CHN",
                 "country_code_iso2" => "CN",
                 "province" => "北京市",
                 "city" => "北京市",
                 "city_level" => 2,
                 "district" => "东城区",
                 "town" => "东华门街道",
                 "town_code" => "110101001",
                 "distance" => "78",
                 "direction" => "西南",
                 "adcode" => "110101",
                 "street" => "中华路",
                 "street_number" => "甲10号"
               },
               "pois" => [
                 %{
                   "addr" => "北京市东城区长安街",
                   "cp" => "",
                   "direction" => "内",
                   "distance" => "0",
                   "name" => "天安门",
                   "poiType" => "旅游景点",
                   "point" => %{"x" => 116.39758243596593, "y" => 39.908769258864616},
                   "tag" => "旅游景点;人文景观",
                   "tel" => "",
                   "uid" => "65e1ee886c885190f60e77ff",
                   "zip" => "",
                   "popularity_level" => "1",
                   "aoi_name" => "",
                   "parent_poi" => %{
                     "name" => "",
                     "tag" => "",
                     "addr" => "",
                     "point" => %{"x" => 0, "y" => 0},
                     "direction" => "",
                     "distance" => "",
                     "uid" => "",
                     "popularity_level" => ""
                   }
                 },
                 %{
                   "addr" => "北京市东城区东长安街天安门内",
                   "cp" => "",
                   "direction" => "西北",
                   "distance" => "114",
                   "name" => "天安门-前石狮子",
                   "poiType" => "旅游景点",
                   "point" => %{"x" => 116.397923453495, "y" => 39.908090350478155},
                   "tag" => "旅游景点",
                   "tel" => "",
                   "uid" => "25a0088af2e3b35cd8ecedf6",
                   "zip" => "",
                   "popularity_level" => "9",
                   "aoi_name" => "",
                   "parent_poi" => %{
                     "name" => "天安门广场",
                     "tag" => "旅游景点;文物古迹",
                     "addr" => "北京市东城区东长安街",
                     "point" => %{"x" => 116.39779308805923, "y" => 39.9033018939856},
                     "direction" => "北",
                     "distance" => "787",
                     "uid" => "c9b5fb91d49345bc5d0d0262",
                     "popularity_level" => "9"
                   }
                 }
               ]
             }
           },
           headers: [{"content-type", "application/json"}],
           status: 200
         }}
      end do
      assert BaiduMap.reverse_lookup(39.907333, 116.391083, "zh", %{
               ak: "test",
               sk: "test"
             }) ==
               {
                 :ok,
                 %{
                   city: "北京市",
                   country: "中国",
                   county: "东城区",
                   display_name: "北京市东城区东华门街道天安门",
                   house_number: "甲10号",
                   latitude: 39.907336,
                   longitude: 116.391086,
                   name: "天安门",
                   neighbourhood: "东华门街道",
                   osm_id: 3_065_298_148,
                   osm_type: "node",
                   postcode: "",
                   raw: %{
                     "addressComponent" => %{
                       "adcode" => "110101",
                       "city" => "北京市",
                       "city_level" => 2,
                       "country" => "中国",
                       "country_code" => 0,
                       "country_code_iso" => "CHN",
                       "country_code_iso2" => "CN",
                       "direction" => "西南",
                       "distance" => "78",
                       "district" => "东城区",
                       "province" => "北京市",
                       "street" => "中华路",
                       "street_number" => "甲10号",
                       "town" => "东华门街道",
                       "town_code" => "110101001"
                     },
                     "business" => "前门,王府井",
                     "formatted_address" => "北京市东城区东华门街道中华路甲10号",
                     "formatted_address_poi" => "北京市东城区东华门街道天安门",
                     "location" => %{"lat" => 39.90873911887158, "lng" => 116.39732983405372},
                     "pois" => [
                       %{
                         "addr" => "北京市东城区长安街",
                         "aoi_name" => "",
                         "cp" => "",
                         "direction" => "内",
                         "distance" => "0",
                         "name" => "天安门",
                         "parent_poi" => %{
                           "addr" => "",
                           "direction" => "",
                           "distance" => "",
                           "name" => "",
                           "point" => %{"x" => 0, "y" => 0},
                           "popularity_level" => "",
                           "tag" => "",
                           "uid" => ""
                         },
                         "poiType" => "旅游景点",
                         "point" => %{"x" => 116.39758243596593, "y" => 39.908769258864616},
                         "popularity_level" => "1",
                         "tag" => "旅游景点;人文景观",
                         "tel" => "",
                         "uid" => "65e1ee886c885190f60e77ff",
                         "zip" => ""
                       }
                     ]
                   },
                   road: "中华路",
                   state: "北京市",
                   state_district: nil
                 }
               }
    end
  end
end
