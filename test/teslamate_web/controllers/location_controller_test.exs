defmodule TeslaMateWeb.LocationControllerTest do
  use TeslaMateWeb.ConnCase

  import Mock

  alias TeslaMate.Locations.Geocoder

  describe "geocoder_reverse/2" do
    test "uses lang from query params when provided", %{conn: conn} do
      with_mock Geocoder, reverse_lookup: fn _, _, _ -> {:ok, %{address: "Test Address"}} end do
        conn =
          conn
          |> get("/api/location/geocoder/reverse", %{
            "lat" => "39.9042",
            "lon" => "116.4074",
            "lang" => "zh"
          })

        assert json_response(conn, 200) == %{"address" => "Test Address"}
        assert called(Geocoder.reverse_lookup(39.9042, 116.4074, "zh"))
      end
    end

    test "uses accept-language header when lang query param is missing", %{conn: conn} do
      with_mock Geocoder, reverse_lookup: fn _, _, _ -> {:ok, %{address: "Test Address"}} end do
        conn =
          conn
          |> put_req_header("accept-language", "zh-CN,zh;q=0.9,en;q=0.8")
          |> get("/api/location/geocoder/reverse", %{"lat" => "39.9042", "lon" => "116.4074"})

        assert json_response(conn, 200) == %{"address" => "Test Address"}
        assert called(Geocoder.reverse_lookup(39.9042, 116.4074, "zh-CN"))
      end
    end

    test "defaults to 'en' when no lang param and no accept-language header", %{conn: conn} do
      with_mock Geocoder, reverse_lookup: fn _, _, _ -> {:ok, %{address: "Test Address"}} end do
        conn =
          conn
          |> get("/api/location/geocoder/reverse", %{"lat" => "39.9042", "lon" => "116.4074"})

        assert json_response(conn, 200) == %{"address" => "Test Address"}
        assert called(Geocoder.reverse_lookup(39.9042, 116.4074, "en"))
      end
    end

    test "handles various accept-language header formats", %{conn: conn} do
      test_cases = [
        {"zh-CN", "zh-CN"},
        {"zh-TW,zh;q=0.9", "zh-TW"},
        {"zh-HK,zh;q=0.9", "zh-HK"},
        {"fr-FR,fr;q=0.9,en;q=0.8", "fr-FR"},
        {"ja-JP,ja;q=0.9", "ja-JP"},
        {"en-US,en;q=0.9", "en-US"},
        {"de", "de"},
        {"invalid", "invalid"},
        {"", "en"}
      ]

      with_mock Geocoder, reverse_lookup: fn _, _, _ -> {:ok, %{address: "Test Address"}} end do
        for {accept_lang, expected_lang} <- test_cases do
          conn_with_header =
            if accept_lang != "" do
              put_req_header(conn, "accept-language", accept_lang)
            else
              conn
            end

          response_conn =
            conn_with_header
            |> get("/api/location/geocoder/reverse", %{"lat" => "39.9042", "lon" => "116.4074"})

          assert json_response(response_conn, 200) == %{"address" => "Test Address"}
          assert called(Geocoder.reverse_lookup(39.9042, 116.4074, expected_lang))
        end
      end
    end

    test "returns error for invalid coordinates", %{conn: conn} do
      conn =
        conn
        |> get("/api/location/geocoder/reverse", %{"lat" => "invalid", "lon" => "116.4074"})

      assert json_response(conn, 400) == %{"error" => "Invalid latitude or longitude"}
    end

    test "returns error for missing coordinates", %{conn: conn} do
      conn =
        conn
        |> get("/api/location/geocoder/reverse", %{"lat" => "39.9042"})

      assert json_response(conn, 400) == %{"error" => "Missing latitude or longitude"}
    end

    test "returns error when geocoder fails", %{conn: conn} do
      with_mock Geocoder, reverse_lookup: fn _, _, _ -> {:error, "Geocoding failed"} end do
        conn =
          conn
          |> get("/api/location/geocoder/reverse", %{"lat" => "39.9042", "lon" => "116.4074"})

        assert json_response(conn, 400) == %{"error" => "Geocoding failed"}
      end
    end

    test "handles quality values in accept-language header", %{conn: conn} do
      with_mock Geocoder, reverse_lookup: fn _, _, _ -> {:ok, %{address: "Test Address"}} end do
        conn =
          conn
          |> put_req_header("accept-language", "zh-CN;q=0.9,en;q=0.8,fr;q=0.7")
          |> get("/api/location/geocoder/reverse", %{"lat" => "39.9042", "lon" => "116.4074"})

        assert json_response(conn, 200) == %{"address" => "Test Address"}
        assert called(Geocoder.reverse_lookup(39.9042, 116.4074, "zh-CN"))
      end
    end

    test "prioritizes query param over accept-language header", %{conn: conn} do
      with_mock Geocoder, reverse_lookup: fn _, _, _ -> {:ok, %{address: "Test Address"}} end do
        conn =
          conn
          |> put_req_header("accept-language", "zh-CN,zh;q=0.9")
          |> get("/api/location/geocoder/reverse", %{
            "lat" => "39.9042",
            "lon" => "116.4074",
            "lang" => "fr"
          })

        assert json_response(conn, 200) == %{"address" => "Test Address"}
        assert called(Geocoder.reverse_lookup(39.9042, 116.4074, "fr"))
      end
    end
  end
end
