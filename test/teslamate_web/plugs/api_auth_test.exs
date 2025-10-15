defmodule TeslaMateWeb.Plugs.ApiAuthTest do
  use TeslaMateWeb.ConnCase

  alias TeslaMateWeb.Plugs.ApiAuth
  alias TeslaMate.WebAuth, as: WebAuthCore

  describe "ApiAuth Plug" do
    test "passes through when no password authentication required", %{conn: conn} do
      # 确保没有设置密码
      System.delete_env("WEB_AUTH_PASS")

      conn =
        conn
        |> put_req_header("accept", "application/json")

      result_conn = ApiAuth.call(conn, [])

      # 应该正常通过
      refute result_conn.halted
    end

    test "authenticates with valid Basic Auth", %{conn: conn} do
      # 设置测试密码
      System.put_env("WEB_AUTH_PASS", "test_password")

      # 创建Basic Auth头
      credentials = Base.encode64("user:test_password")

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Basic #{credentials}")

      result_conn = ApiAuth.call(conn, [])

      # 应该正常通过
      refute result_conn.halted

      # 清除环境变量
      System.delete_env("WEB_AUTH_PASS")
    end

    test "rejects invalid Basic Auth credentials", %{conn: conn} do
      # 设置测试密码
      System.put_env("WEB_AUTH_PASS", "test_password")

      # 创建错误的Basic Auth头
      credentials = Base.encode64("user:wrong_password")

      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Basic #{credentials}")

      result_conn = ApiAuth.call(conn, [])

      # 应该被拒绝
      assert result_conn.halted
      assert result_conn.status == 401

      # 检查响应内容
      response_body = Jason.decode!(result_conn.resp_body)
      assert response_body["error"] == "authentication_failed"
      assert response_body["message"] == "Invalid credentials"

      # 检查WWW-Authenticate头
      assert get_resp_header(result_conn, "www-authenticate") == ["Basic realm=\"TeslaMate API\""]

      # 清除环境变量
      System.delete_env("WEB_AUTH_PASS")
    end

    test "authenticates with valid session", %{conn: conn} do
      # 设置测试密码
      System.put_env("WEB_AUTH_PASS", "test_password")

      # 创建已认证的会话
      conn =
        conn
        |> init_test_session(%{})
        |> WebAuthCore.authenticate()
        |> put_req_header("accept", "application/json")

      result_conn = ApiAuth.call(conn, [])

      # 应该正常通过
      refute result_conn.halted

      # 清除环境变量
      System.delete_env("WEB_AUTH_PASS")
    end

    test "Basic Auth takes priority over session", %{conn: conn} do
      # 设置测试密码
      System.put_env("WEB_AUTH_PASS", "test_password")

      # 创建已认证的会话，但使用错误的Basic Auth
      credentials = Base.encode64("user:wrong_password")

      conn =
        conn
        |> init_test_session(%{})
        # 有效会话
        |> WebAuthCore.authenticate()
        |> put_req_header("accept", "application/json")
        # 无效Basic Auth
        |> put_req_header("authorization", "Basic #{credentials}")

      result_conn = ApiAuth.call(conn, [])

      # Basic Auth优先，应该被拒绝
      assert result_conn.halted
      assert result_conn.status == 401

      # 清除环境变量
      System.delete_env("WEB_AUTH_PASS")
    end

    test "rejects request with no authentication", %{conn: conn} do
      # 设置测试密码
      System.put_env("WEB_AUTH_PASS", "test_password")

      conn =
        conn
        |> init_test_session(%{})
        |> put_req_header("accept", "application/json")

      result_conn = ApiAuth.call(conn, [])

      # 应该被拒绝
      assert result_conn.halted
      assert result_conn.status == 401

      # 检查响应内容
      response_body = Jason.decode!(result_conn.resp_body)
      assert response_body["error"] == "authentication_failed"
      assert response_body["message"] == "Authentication required"

      # 清除环境变量
      System.delete_env("WEB_AUTH_PASS")
    end

    test "handles malformed Basic Auth header", %{conn: conn} do
      # 设置测试密码
      System.put_env("WEB_AUTH_PASS", "test_password")

      conn =
        conn
        |> init_test_session(%{})
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Basic invalid_base64")

      result_conn = ApiAuth.call(conn, [])

      # 应该被拒绝
      assert result_conn.halted
      assert result_conn.status == 401

      # 清除环境变量
      System.delete_env("WEB_AUTH_PASS")
    end

    test "handles Basic Auth without password part", %{conn: conn} do
      # 设置测试密码
      System.put_env("WEB_AUTH_PASS", "test_password")

      # 只有用户名，没有密码部分
      credentials = Base.encode64("user_only")

      conn =
        conn
        |> init_test_session(%{})
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Basic #{credentials}")

      result_conn = ApiAuth.call(conn, [])

      # 应该被拒绝
      assert result_conn.halted
      assert result_conn.status == 401

      # 清除环境变量
      System.delete_env("WEB_AUTH_PASS")
    end

    test "rejects request with no session and no auth header", %{conn: conn} do
      # 设置测试密码
      System.put_env("WEB_AUTH_PASS", "test_password")

      # 不初始化会话
      conn =
        conn
        |> put_req_header("accept", "application/json")

      result_conn = ApiAuth.call(conn, [])

      # 应该被拒绝
      assert result_conn.halted
      assert result_conn.status == 401

      # 检查响应内容
      response_body = Jason.decode!(result_conn.resp_body)
      assert response_body["error"] == "authentication_failed"
      assert response_body["message"] == "Authentication required"

      # 清除环境变量
      System.delete_env("WEB_AUTH_PASS")
    end
  end
end
