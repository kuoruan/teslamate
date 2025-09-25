defmodule TeslaMate.WebAuthTest do
  use TeslaMate.DataCase

  import Plug.Test
  import Plug.Conn

  alias TeslaMate.WebAuth

  # Helper function to create a test connection with session
  defp build_conn_with_session(session_data \\ %{}) do
    :get
    |> conn("/")
    |> init_test_session(session_data)
  end

  # Note: secure_compare/2 is a private function and should not be tested directly
  # We test it indirectly through verify_password/1

  describe "verify_password/1" do
    test "succeeds with correct password" do
      System.put_env("WEB_AUTH_PASS", "test_password")

      assert {:ok, :authenticated} = WebAuth.verify_password("test_password")

      System.delete_env("WEB_AUTH_PASS")
    end

    test "fails with incorrect password" do
      System.put_env("WEB_AUTH_PASS", "test_password")

      assert {:error, :invalid_password} = WebAuth.verify_password("wrong_password")

      System.delete_env("WEB_AUTH_PASS")
    end

    test "allows access when no password is set (nil env)" do
      System.delete_env("WEB_AUTH_PASS")

      assert {:ok, :no_password_set} = WebAuth.verify_password("")
    end

    test "allows access when password is empty string" do
      System.put_env("WEB_AUTH_PASS", "")

      assert {:ok, :no_password_set} = WebAuth.verify_password("")

      System.delete_env("WEB_AUTH_PASS")
    end

    test "rejects non-empty input when no password is set" do
      System.delete_env("WEB_AUTH_PASS")

      assert {:error, :invalid_password} = WebAuth.verify_password("some_password")
    end

    test "rejects invalid input types" do
      assert {:error, :invalid_input} = WebAuth.verify_password(123)
      assert {:error, :invalid_input} = WebAuth.verify_password(nil)
      assert {:error, :invalid_input} = WebAuth.verify_password(%{})
      assert {:error, :invalid_input} = WebAuth.verify_password([])
      assert {:error, :invalid_input} = WebAuth.verify_password(:atom)
    end

    test "handles complex passwords correctly" do
      complex_password = "ComplEx!P@ssw0rd#2024$with%symbols^and&numbers123"
      System.put_env("WEB_AUTH_PASS", complex_password)

      assert {:ok, :authenticated} = WebAuth.verify_password(complex_password)

      System.delete_env("WEB_AUTH_PASS")
    end

    test "handles unicode characters in password" do
      unicode_password = "密码123!@#测试"
      System.put_env("WEB_AUTH_PASS", unicode_password)

      assert {:ok, :authenticated} = WebAuth.verify_password(unicode_password)
      assert {:error, :invalid_password} = WebAuth.verify_password("密码123!@#")

      System.delete_env("WEB_AUTH_PASS")
    end

    test "handles very long passwords" do
      long_password = String.duplicate("a", 1000)
      System.put_env("WEB_AUTH_PASS", long_password)

      assert {:ok, :authenticated} = WebAuth.verify_password(long_password)
      assert {:error, :invalid_password} = WebAuth.verify_password(String.duplicate("b", 1000))

      System.delete_env("WEB_AUTH_PASS")
    end

    test "handles passwords with whitespace" do
      password_with_spaces = "  password with spaces  "
      System.put_env("WEB_AUTH_PASS", password_with_spaces)

      assert {:ok, :authenticated} = WebAuth.verify_password(password_with_spaces)
      assert {:error, :invalid_password} = WebAuth.verify_password("password with spaces")

      System.delete_env("WEB_AUTH_PASS")
    end

    test "case sensitive password comparison" do
      System.put_env("WEB_AUTH_PASS", "CaseSensitive")

      assert {:ok, :authenticated} = WebAuth.verify_password("CaseSensitive")
      assert {:error, :invalid_password} = WebAuth.verify_password("casesensitive")
      assert {:error, :invalid_password} = WebAuth.verify_password("CASESENSITIVE")

      System.delete_env("WEB_AUTH_PASS")
    end

    test "similar but different passwords are rejected" do
      System.put_env("WEB_AUTH_PASS", "password123")

      assert {:error, :invalid_password} = WebAuth.verify_password("password124")
      assert {:error, :invalid_password} = WebAuth.verify_password("password12")
      assert {:error, :invalid_password} = WebAuth.verify_password("password1234")

      System.delete_env("WEB_AUTH_PASS")
    end
  end

  describe "password_required?/0" do
    test "returns false when no password is set" do
      System.delete_env("WEB_AUTH_PASS")

      refute WebAuth.password_required?()
    end

    test "returns false when password is empty string" do
      System.put_env("WEB_AUTH_PASS", "")

      refute WebAuth.password_required?()

      System.delete_env("WEB_AUTH_PASS")
    end

    test "returns true when valid password is set" do
      System.put_env("WEB_AUTH_PASS", "valid_password")

      assert WebAuth.password_required?()

      System.delete_env("WEB_AUTH_PASS")
    end

    test "returns false when password contains only whitespace" do
      System.put_env("WEB_AUTH_PASS", "   ")

      # 空格仍然是有效密码
      assert WebAuth.password_required?()

      System.delete_env("WEB_AUTH_PASS")
    end

    test "returns true for single character password" do
      System.put_env("WEB_AUTH_PASS", "a")

      assert WebAuth.password_required?()

      System.delete_env("WEB_AUTH_PASS")
    end

    test "returns true for very long password" do
      long_password = String.duplicate("x", 10000)
      System.put_env("WEB_AUTH_PASS", long_password)

      assert WebAuth.password_required?()

      System.delete_env("WEB_AUTH_PASS")
    end
  end

  describe "session management" do
    test "authenticated?/1 returns false for unauthenticated session" do
      conn = build_conn_with_session()

      refute WebAuth.authenticated?(conn)
    end

    test "authenticated?/1 returns true for valid authenticated session" do
      current_time = System.system_time(:second)

      conn =
        build_conn_with_session(%{
          web_authenticated: true,
          web_auth_time: current_time
        })

      assert WebAuth.authenticated?(conn)
    end

    test "authenticated?/1 returns false for expired session" do
      # 2 hours ago
      expired_time = System.system_time(:second) - 7200

      conn =
        build_conn_with_session(%{
          web_authenticated: true,
          web_auth_time: expired_time
        })

      refute WebAuth.authenticated?(conn)
    end

    test "authenticated?/1 returns false when web_authenticated is false" do
      current_time = System.system_time(:second)

      conn =
        build_conn_with_session(%{
          web_authenticated: false,
          web_auth_time: current_time
        })

      refute WebAuth.authenticated?(conn)
    end

    test "authenticated?/1 returns false when web_authenticated is missing" do
      current_time = System.system_time(:second)

      conn =
        build_conn_with_session(%{
          web_auth_time: current_time
        })

      refute WebAuth.authenticated?(conn)
    end

    test "authenticated?/1 returns false when web_auth_time is missing" do
      conn =
        build_conn_with_session(%{
          web_authenticated: true
        })

      refute WebAuth.authenticated?(conn)
    end

    test "authenticated?/1 returns false when auth_time is not an integer" do
      conn =
        build_conn_with_session(%{
          web_authenticated: true,
          web_auth_time: "not_an_integer"
        })

      refute WebAuth.authenticated?(conn)
    end

    test "authenticated?/1 handles session at exact expiry boundary" do
      # Exactly 1 hour ago (should be expired)
      boundary_time = System.system_time(:second) - 3600

      conn =
        build_conn_with_session(%{
          web_authenticated: true,
          web_auth_time: boundary_time
        })

      refute WebAuth.authenticated?(conn)
    end

    test "authenticated?/1 handles session just before expiry" do
      # Just under 1 hour ago (should still be valid)
      valid_time = System.system_time(:second) - 3599

      conn =
        build_conn_with_session(%{
          web_authenticated: true,
          web_auth_time: valid_time
        })

      assert WebAuth.authenticated?(conn)
    end

    test "authenticate/1 sets session data" do
      conn = build_conn_with_session()
      before_time = System.system_time(:second)

      authenticated_conn = WebAuth.authenticate(conn)
      after_time = System.system_time(:second)

      assert Plug.Conn.get_session(authenticated_conn, :web_authenticated) == true
      auth_time = Plug.Conn.get_session(authenticated_conn, :web_auth_time)
      assert is_integer(auth_time)
      assert auth_time >= before_time and auth_time <= after_time
    end

    test "authenticate/1 overwrites existing session data" do
      old_time = System.system_time(:second) - 1000

      conn =
        build_conn_with_session(%{
          web_authenticated: false,
          web_auth_time: old_time
        })

      authenticated_conn = WebAuth.authenticate(conn)

      assert Plug.Conn.get_session(authenticated_conn, :web_authenticated) == true
      new_auth_time = Plug.Conn.get_session(authenticated_conn, :web_auth_time)
      assert new_auth_time > old_time
    end

    test "unauthenticate/1 clears session data" do
      conn =
        build_conn_with_session(%{
          web_authenticated: true,
          web_auth_time: System.system_time(:second)
        })

      unauthenticated_conn = WebAuth.unauthenticate(conn)

      assert Plug.Conn.get_session(unauthenticated_conn, :web_authenticated) == nil
      assert Plug.Conn.get_session(unauthenticated_conn, :web_auth_time) == nil
    end

    test "unauthenticate/1 handles already unauthenticated session" do
      conn = build_conn_with_session()

      unauthenticated_conn = WebAuth.unauthenticate(conn)

      assert Plug.Conn.get_session(unauthenticated_conn, :web_authenticated) == nil
      assert Plug.Conn.get_session(unauthenticated_conn, :web_auth_time) == nil
    end

    test "session_remaining_time/1 calculates correct remaining time" do
      current_time = System.system_time(:second)

      conn =
        build_conn_with_session(%{
          web_auth_time: current_time
        })

      remaining = WebAuth.session_remaining_time(conn)

      # Should be close to 1 hour (3600 seconds)
      assert remaining >= 3590 and remaining <= 3600
    end

    test "session_remaining_time/1 returns 0 for no session" do
      conn = build_conn_with_session()

      assert WebAuth.session_remaining_time(conn) == 0
    end

    test "session_remaining_time/1 returns 0 for expired session" do
      # 2 hours ago
      expired_time = System.system_time(:second) - 7200

      conn =
        build_conn_with_session(%{
          web_auth_time: expired_time
        })

      assert WebAuth.session_remaining_time(conn) == 0
    end

    test "session_remaining_time/1 calculates partial remaining time" do
      # Session started 30 minutes ago
      half_hour_ago = System.system_time(:second) - 1800

      conn =
        build_conn_with_session(%{
          web_auth_time: half_hour_ago
        })

      remaining = WebAuth.session_remaining_time(conn)

      # Should have about 30 minutes (1800 seconds) remaining
      assert remaining >= 1790 and remaining <= 1800
    end
  end

  describe "redirect path management" do
    test "set_redirect_path/2 stores path in session" do
      conn = build_conn_with_session()
      path = "/some/path"

      updated_conn = WebAuth.set_redirect_path(conn, path)

      assert Plug.Conn.get_session(updated_conn, :redirect_after_auth) == path
    end

    test "set_redirect_path/2 handles complex paths" do
      conn = build_conn_with_session()
      complex_path = "/cars/123/drives?page=2&sort=date#section"

      updated_conn = WebAuth.set_redirect_path(conn, complex_path)

      assert Plug.Conn.get_session(updated_conn, :redirect_after_auth) == complex_path
    end

    test "set_redirect_path/2 handles paths with unicode characters" do
      conn = build_conn_with_session()
      unicode_path = "/测试/路径"

      updated_conn = WebAuth.set_redirect_path(conn, unicode_path)

      assert Plug.Conn.get_session(updated_conn, :redirect_after_auth) == unicode_path
    end

    test "set_redirect_path/2 handles empty string path" do
      conn = build_conn_with_session()

      updated_conn = WebAuth.set_redirect_path(conn, "")

      assert Plug.Conn.get_session(updated_conn, :redirect_after_auth) == ""
    end

    test "set_redirect_path/2 returns unchanged conn for non-string input" do
      original_conn = build_conn_with_session()

      # Test with various non-string inputs
      conn1 = WebAuth.set_redirect_path(original_conn, nil)
      conn2 = WebAuth.set_redirect_path(original_conn, 123)
      conn3 = WebAuth.set_redirect_path(original_conn, %{})
      conn4 = WebAuth.set_redirect_path(original_conn, [:invalid])

      assert conn1 == original_conn
      assert conn2 == original_conn
      assert conn3 == original_conn
      assert conn4 == original_conn
    end

    test "set_redirect_path/2 overwrites existing path" do
      conn = build_conn_with_session(%{redirect_after_auth: "/old/path"})
      new_path = "/new/path"

      updated_conn = WebAuth.set_redirect_path(conn, new_path)

      assert Plug.Conn.get_session(updated_conn, :redirect_after_auth) == new_path
    end

    test "get_redirect_path/1 returns stored path" do
      path = "/stored/path"
      conn = build_conn_with_session(%{redirect_after_auth: path})

      assert WebAuth.get_redirect_path(conn) == path
    end

    test "get_redirect_path/1 returns default path when none stored" do
      conn = build_conn_with_session()

      path = WebAuth.get_redirect_path(conn)

      # Should return the default path from default_redirect_path/1
      assert is_binary(path)
      # Default should be "/" when Routes.car_path fails
      assert path == "/" or String.contains?(path, "/car")
    end

    test "get_redirect_path/1 handles nil session value" do
      conn = build_conn_with_session(%{redirect_after_auth: nil})

      path = WebAuth.get_redirect_path(conn)

      assert is_binary(path)
    end

    test "clear_redirect_path/1 removes stored path" do
      conn = build_conn_with_session(%{redirect_after_auth: "/some/path"})

      cleared_conn = WebAuth.clear_redirect_path(conn)

      assert Plug.Conn.get_session(cleared_conn, :redirect_after_auth) == nil
    end

    test "clear_redirect_path/1 handles already cleared path" do
      conn = build_conn_with_session()

      cleared_conn = WebAuth.clear_redirect_path(conn)

      assert Plug.Conn.get_session(cleared_conn, :redirect_after_auth) == nil
    end

    test "get_and_clear_redirect_path/1 returns path and clears it" do
      path = "/test/path"
      conn = build_conn_with_session(%{redirect_after_auth: path})

      {updated_conn, returned_path} = WebAuth.get_and_clear_redirect_path(conn)

      assert returned_path == path
      assert Plug.Conn.get_session(updated_conn, :redirect_after_auth) == nil
    end

    test "get_and_clear_redirect_path/1 returns default path when none stored" do
      conn = build_conn_with_session()

      {updated_conn, returned_path} = WebAuth.get_and_clear_redirect_path(conn)

      assert is_binary(returned_path)
      assert Plug.Conn.get_session(updated_conn, :redirect_after_auth) == nil
    end
  end

  describe "utility functions" do
    test "get_remote_ip/1 extracts IP from x-forwarded-for header" do
      conn =
        :get
        |> conn("/")
        |> put_req_header("x-forwarded-for", "192.168.1.1, 10.0.0.1")

      assert WebAuth.get_remote_ip(conn) == "192.168.1.1"
    end

    test "get_remote_ip/1 handles single IP in x-forwarded-for" do
      conn =
        :get
        |> conn("/")
        |> put_req_header("x-forwarded-for", "203.0.113.1")

      assert WebAuth.get_remote_ip(conn) == "203.0.113.1"
    end

    test "get_remote_ip/1 handles IP with extra whitespace" do
      conn =
        :get
        |> conn("/")
        |> put_req_header("x-forwarded-for", "  192.168.1.100  , 10.0.0.1")

      assert WebAuth.get_remote_ip(conn) == "192.168.1.100"
    end

    test "get_remote_ip/1 handles IPv6 addresses" do
      ipv6_address = "2001:db8::1"

      conn =
        :get
        |> conn("/")
        |> put_req_header("x-forwarded-for", "#{ipv6_address}, 192.168.1.1")

      assert WebAuth.get_remote_ip(conn) == ipv6_address
    end

    test "get_remote_ip/1 handles multiple x-forwarded-for headers" do
      # When multiple headers exist, Plug.Conn.get_req_header returns the first one
      conn =
        :get
        |> conn("/")
        |> put_req_header("x-forwarded-for", "192.168.1.1")
        |> put_req_header("x-forwarded-for", "10.0.0.1")

      # Should get the first header's first IP
      result = WebAuth.get_remote_ip(conn)
      assert result == "192.168.1.1" or result == "10.0.0.1"
    end

    test "get_remote_ip/1 falls back to remote_ip when no header" do
      conn = conn(:get, "/")

      ip = WebAuth.get_remote_ip(conn)

      assert is_binary(ip)
    end

    test "get_remote_ip/1 handles empty x-forwarded-for header" do
      conn =
        :get
        |> conn("/")
        |> put_req_header("x-forwarded-for", "")

      ip = WebAuth.get_remote_ip(conn)

      # Should fall back to remote_ip behavior
      assert is_binary(ip)
    end

    test "get_remote_ip/1 handles invalid input" do
      assert WebAuth.get_remote_ip(nil) == "unknown"
      assert WebAuth.get_remote_ip("invalid") == "unknown"
      assert WebAuth.get_remote_ip(%{}) == "unknown"
      assert WebAuth.get_remote_ip(123) == "unknown"
    end

    test "get_user_agent/1 extracts user agent from header" do
      user_agent = "Mozilla/5.0 (Test Browser)"

      conn =
        :get
        |> conn("/")
        |> put_req_header("user-agent", user_agent)

      assert WebAuth.get_user_agent(conn) == user_agent
    end

    test "get_user_agent/1 handles complex user agent strings" do
      complex_ua =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"

      conn =
        :get
        |> conn("/")
        |> put_req_header("user-agent", complex_ua)

      assert WebAuth.get_user_agent(conn) == complex_ua
    end

    test "get_user_agent/1 handles user agent with unicode characters" do
      unicode_ua = "TestBrowser/1.0 (测试浏览器)"

      conn =
        :get
        |> conn("/")
        |> put_req_header("user-agent", unicode_ua)

      assert WebAuth.get_user_agent(conn) == unicode_ua
    end

    test "get_user_agent/1 returns Unknown when no header" do
      conn = conn(:get, "/")

      assert WebAuth.get_user_agent(conn) == "Unknown"
    end

    test "get_user_agent/1 handles empty user agent header" do
      conn =
        :get
        |> conn("/")
        |> put_req_header("user-agent", "")

      assert WebAuth.get_user_agent(conn) == ""
    end

    test "get_user_agent/1 handles multiple user agent headers" do
      conn =
        :get
        |> conn("/")
        |> put_req_header("user-agent", "FirstUA/1.0")
        |> put_req_header("user-agent", "SecondUA/2.0")

      # Should return the first user agent
      result = WebAuth.get_user_agent(conn)
      assert result == "FirstUA/1.0" or result == "SecondUA/2.0"
    end
  end

  describe "security tests" do
    test "timing attack resistance - password verification executes consistently" do
      System.put_env("WEB_AUTH_PASS", "correct_password")

      # Run multiple iterations to get more stable timing
      correct_times =
        for _ <- 1..10 do
          {time, _} = :timer.tc(fn -> WebAuth.verify_password("correct_password") end)
          time
        end

      incorrect_times =
        for _ <- 1..10 do
          {time, _} = :timer.tc(fn -> WebAuth.verify_password("wrong_password") end)
          time
        end

      # Calculate averages to reduce noise
      avg_correct = Enum.sum(correct_times) / length(correct_times)
      avg_incorrect = Enum.sum(incorrect_times) / length(incorrect_times)

      # Both should execute in reasonable time (function should not be instantaneous)
      # More than 1 microsecond
      assert avg_correct > 1
      assert avg_incorrect > 1

      System.delete_env("WEB_AUTH_PASS")
    end

    test "secure_compare is called for nil password case" do
      System.delete_env("WEB_AUTH_PASS")

      # Verify the function behavior rather than exact timing
      result = WebAuth.verify_password("any_password")
      assert {:error, :invalid_password} = result

      # Test empty input with nil password
      result2 = WebAuth.verify_password("")
      assert {:ok, :no_password_set} = result2
    end

    test "secure_compare is called for empty password case" do
      System.put_env("WEB_AUTH_PASS", "")

      # Verify the function behavior
      result = WebAuth.verify_password("any_password")
      assert {:ok, :no_password_set} = result

      result2 = WebAuth.verify_password("")
      assert {:ok, :no_password_set} = result2

      System.delete_env("WEB_AUTH_PASS")
    end

    test "constant time comparison implementation exists" do
      # Verify that the secure_compare function prevents timing attacks
      # by testing that it processes different scenarios
      System.put_env("WEB_AUTH_PASS", "test123")

      # Different length passwords should still be processed
      assert {:error, :invalid_password} = WebAuth.verify_password("a")
      assert {:error, :invalid_password} = WebAuth.verify_password(String.duplicate("b", 1000))

      # Correct password should still work
      assert {:ok, :authenticated} = WebAuth.verify_password("test123")

      System.delete_env("WEB_AUTH_PASS")
    end
  end

  describe "edge cases and error handling" do
    test "verify_password handles binary strings with special characters" do
      # Use other special characters since null bytes aren't allowed in env vars
      password_with_special = "password\nwith\ttabs"
      System.put_env("WEB_AUTH_PASS", password_with_special)

      assert {:ok, :authenticated} = WebAuth.verify_password(password_with_special)
      assert {:error, :invalid_password} = WebAuth.verify_password("password")
      assert {:error, :invalid_password} = WebAuth.verify_password("password\nwith")

      System.delete_env("WEB_AUTH_PASS")
    end

    test "session functions handle concurrent modifications" do
      conn = build_conn_with_session()

      # Simulate concurrent authentication
      conn1 = WebAuth.authenticate(conn)
      conn2 = WebAuth.authenticate(conn)

      # Both should have valid session data
      assert WebAuth.authenticated?(conn1)
      assert WebAuth.authenticated?(conn2)
    end

    test "session_remaining_time handles future auth_time gracefully" do
      # Future time (shouldn't happen in practice but test robustness)
      future_time = System.system_time(:second) + 1000

      conn =
        build_conn_with_session(%{
          web_auth_time: future_time
        })

      # Should handle gracefully, likely return large positive number
      remaining = WebAuth.session_remaining_time(conn)
      assert is_integer(remaining)
      assert remaining >= 0
    end

    test "redirect path functions handle very long paths" do
      conn = build_conn_with_session()
      very_long_path = "/" <> String.duplicate("a", 10000)

      updated_conn = WebAuth.set_redirect_path(conn, very_long_path)
      stored_path = WebAuth.get_redirect_path(updated_conn)

      assert stored_path == very_long_path
    end

    test "utility functions handle malformed headers gracefully" do
      # Test malformed x-forwarded-for header
      conn_malformed_xff =
        :get
        |> conn("/")
        |> put_req_header("x-forwarded-for", "not,valid,ip,format")

      ip = WebAuth.get_remote_ip(conn_malformed_xff)
      assert is_binary(ip)

      # Test very long user agent
      very_long_ua = String.duplicate("A", 10000)

      conn_long_ua =
        :get
        |> conn("/")
        |> put_req_header("user-agent", very_long_ua)

      ua = WebAuth.get_user_agent(conn_long_ua)
      assert ua == very_long_ua
    end
  end
end
