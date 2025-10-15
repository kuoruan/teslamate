defmodule TeslaMateWeb.ApiAuthIntegrationTest do
  use TeslaMateWeb.ConnCase

  import Mock

  alias TeslaMate.WebAuth

  # Mock HTTP responses to avoid external dependencies
  defp http_mock do
    {Tesla.Adapter.Finch, [],
     call: fn %Tesla.Env{}, _opts ->
       env = %Tesla.Env{
         body: %{
           "display_name" => "Test Location",
           "address" => %{
             "city" => "Test City",
             "country" => "Test Country"
           }
         },
         headers: [{"content-type", "application/json"}],
         status: 200
       }

       {:ok, env}
     end}
  end

  describe "API Authentication Simple Integration" do
    test "API endpoint requires authentication when password is set", %{conn: conn} do
      with_mocks [http_mock()] do
        # 设置测试密码
        System.put_env("WEB_AUTH_PASS", "test_password")

        # 尝试不带认证访问API
        conn = get(conn, "/api/location/geocoder/reverse?lat=40.7128&lon=-74.0060")

        # 应该返回401未授权
        assert conn.status == 401
        response = json_response(conn, 401)
        assert response["error"] == "authentication_failed"
        assert response["message"] == "Authentication required"

        # 清除环境变量
        System.delete_env("WEB_AUTH_PASS")
      end
    end

    test "API endpoint works with valid Basic Auth", %{conn: conn} do
      with_mocks [http_mock()] do
        # 设置测试密码
        System.put_env("WEB_AUTH_PASS", "test_password")

        # 创建Basic Auth头
        credentials = Base.encode64("user:test_password")

        # 使用Basic Auth访问API
        conn =
          conn
          |> put_req_header("authorization", "Basic #{credentials}")
          |> get("/api/location/geocoder/reverse?lat=40.7128&lon=-74.0060")

        # 认证应该成功（可能因为geocoder服务问题返回其他状态，但不是401）
        refute conn.status == 401

        # 清除环境变量
        System.delete_env("WEB_AUTH_PASS")
      end
    end

    test "API endpoint rejects invalid Basic Auth", %{conn: conn} do
      with_mocks [http_mock()] do
        # 设置测试密码
        System.put_env("WEB_AUTH_PASS", "test_password")

        # 创建错误的Basic Auth头
        credentials = Base.encode64("user:wrong_password")

        # 使用错误的Basic Auth访问API
        conn =
          conn
          |> put_req_header("authorization", "Basic #{credentials}")
          |> get("/api/location/geocoder/reverse?lat=40.7128&lon=-74.0060")

        # 应该返回401未授权
        assert conn.status == 401
        response = json_response(conn, 401)
        assert response["error"] == "authentication_failed"
        assert response["message"] == "Invalid credentials"

        # 检查WWW-Authenticate头
        assert get_resp_header(conn, "www-authenticate") == ["Basic realm=\"TeslaMate API\""]

        # 清除环境变量
        System.delete_env("WEB_AUTH_PASS")
      end
    end

    test "API endpoint works without authentication when no password is set", %{conn: conn} do
      with_mocks [http_mock()] do
        # 确保没有设置密码
        System.delete_env("WEB_AUTH_PASS")

        # 不带认证访问API
        conn = get(conn, "/api/location/geocoder/reverse?lat=40.7128&lon=-74.0060")

        # 认证应该成功（可能因为geocoder服务问题返回其他状态，但不是401）
        refute conn.status == 401
      end
    end

    test "API endpoint works with valid session authentication", %{conn: conn} do
      with_mocks [http_mock()] do
        # 设置测试密码
        System.put_env("WEB_AUTH_PASS", "test_password")

        # 创建已认证的会话
        conn =
          conn
          |> init_test_session(%{})
          |> WebAuth.authenticate()
          |> get("/api/location/geocoder/reverse?lat=40.7128&lon=-74.0060")

        # 认证应该成功（可能因为geocoder服务问题返回其他状态，但不是401）
        refute conn.status == 401

        # 清除环境变量
        System.delete_env("WEB_AUTH_PASS")
      end
    end

    test "Basic Auth takes priority over session", %{conn: conn} do
      with_mocks [http_mock()] do
        # 设置测试密码
        System.put_env("WEB_AUTH_PASS", "test_password")

        # 创建已认证的会话，但使用错误的Basic Auth
        credentials = Base.encode64("user:wrong_password")

        conn =
          conn
          |> init_test_session(%{})
          # 有效会话
          |> WebAuth.authenticate()
          # 无效Basic Auth
          |> put_req_header("authorization", "Basic #{credentials}")
          |> get("/api/location/geocoder/reverse?lat=40.7128&lon=-74.0060")

        # Basic Auth优先，应该被拒绝
        assert conn.status == 401
        response = json_response(conn, 401)
        assert response["error"] == "authentication_failed"

        # 清除环境变量
        System.delete_env("WEB_AUTH_PASS")
      end
    end
  end
end
