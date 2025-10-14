defmodule TeslaMateWeb.Plugs.WebAuthTest do
  use TeslaMateWeb.ConnCase

  alias TeslaMateWeb.Plugs.WebAuth
  alias TeslaMate.WebAuth, as: WebAuthCore

  describe "WebAuth Plug" do
    test "authenticated user accessing auth pages redirects to root", %{conn: conn} do
      # 设置需要密码认证的环境
      System.put_env("WEB_AUTH_PASS", "test_password")

      # 创建已认证的连接
      conn =
        conn
        |> init_test_session(%{})
        |> WebAuthCore.authenticate()

      # 测试访问 /web-auth/index
      conn_index = %{conn | request_path: "/web-auth/index"}
      result_conn = WebAuth.call(conn_index, [])

      # 应该重定向到根目录
      assert redirected_to(result_conn) == "/"
      assert result_conn.halted == true

      # 清除环境变量
      System.delete_env("WEB_AUTH_PASS")
    end

    test "authenticated user accessing non-auth pages passes through normally", %{conn: conn} do
      # 设置需要密码认证的环境
      System.put_env("WEB_AUTH_PASS", "test_password")

      # 创建已认证的连接
      conn =
        conn
        |> init_test_session(%{})
        |> WebAuthCore.authenticate()

      # 测试访问普通页面
      conn = %{conn | request_path: "/cars"}
      result_conn = WebAuth.call(conn, [])

      # 应该正常通过，不重定向
      refute result_conn.halted
      assert result_conn.status != 302

      # 清除环境变量
      System.delete_env("WEB_AUTH_PASS")
    end

    test "unauthenticated user accessing auth pages passes through normally", %{conn: conn} do
      # 设置需要密码认证的环境
      System.put_env("WEB_AUTH_PASS", "test_password")

      # 创建未认证的连接
      conn =
        conn
        |> init_test_session(%{})
        |> Map.put(:request_path, "/web-auth/index")

      result_conn = WebAuth.call(conn, [])

      # 应该重定向到认证页面（不会被我们的新逻辑阻止）
      assert redirected_to(result_conn) == "/web-auth/index"
      assert result_conn.halted == true

      # 清除环境变量
      System.delete_env("WEB_AUTH_PASS")
    end

    test "redirect to root when no password authentication required", %{conn: conn} do
      # 确保没有设置密码
      System.delete_env("WEB_AUTH_PASS")

      # 测试访问认证页面
      conn =
        conn
        |> init_test_session(%{})
        |> Map.put(:request_path, "/web-auth/index")

      result_conn = WebAuth.call(conn, [])

      # 应该重定向到根目录
      assert redirected_to(result_conn) == "/"
      assert result_conn.halted == true
    end
  end
end
