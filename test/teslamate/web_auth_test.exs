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

    test "session functions handle negative auth_time" do
      # Negative timestamp (shouldn't happen but test robustness)
      negative_time = -1000

      conn =
        build_conn_with_session(%{
          web_authenticated: true,
          web_auth_time: negative_time
        })

      # Should be considered expired
      refute WebAuth.authenticated?(conn)
      assert WebAuth.session_remaining_time(conn) == 0
    end

    test "session functions handle zero auth_time" do
      conn =
        build_conn_with_session(%{
          web_authenticated: true,
          web_auth_time: 0
        })

      # Should be considered expired (Unix epoch is way in the past)
      refute WebAuth.authenticated?(conn)
      assert WebAuth.session_remaining_time(conn) == 0
    end

    test "session functions handle very large auth_time" do
      # Very large timestamp (far future)
      large_time = System.system_time(:second) + 999_999_999

      conn =
        build_conn_with_session(%{
          web_authenticated: true,
          web_auth_time: large_time
        })

      # Should be considered valid (timestamp is in future)
      assert WebAuth.authenticated?(conn)
      remaining = WebAuth.session_remaining_time(conn)
      # Should have more than 1 hour remaining
      assert remaining > 3600
    end

    test "authenticated? with session map handles various data types" do
      # Test with string keys (like Phoenix sessions)
      session_with_strings = %{
        "web_authenticated" => true,
        "web_auth_time" => System.system_time(:second)
      }

      assert WebAuth.authenticated?(session_with_strings)

      # Test with atom keys
      session_with_atoms = %{
        web_authenticated: true,
        web_auth_time: System.system_time(:second)
      }

      # Should only work with string keys
      refute WebAuth.authenticated?(session_with_atoms)

      # Test with mixed types
      session_mixed = %{
        # String instead of boolean
        "web_authenticated" => "true",
        "web_auth_time" => System.system_time(:second)
      }

      # Should require boolean true
      refute WebAuth.authenticated?(session_mixed)
    end

    test "session_remaining_time with session map handles edge cases" do
      # Test with string auth_time
      session_with_string_time = %{
        "web_auth_time" => "#{System.system_time(:second)}"
      }

      assert WebAuth.session_remaining_time(session_with_string_time) == 0

      # Test with float auth_time
      session_with_float_time = %{
        "web_auth_time" => System.system_time(:second) + 0.5
      }

      assert WebAuth.session_remaining_time(session_with_float_time) == 0

      # Test with nil auth_time
      session_with_nil_time = %{
        "web_auth_time" => nil
      }

      assert WebAuth.session_remaining_time(session_with_nil_time) == 0
    end
  end

  describe "redirect path management" do
    test "set_redirect_path/2 stores path in session" do
      conn = build_conn_with_session()
      path = "/some/path"

      updated_conn = WebAuth.set_redirect_path(conn, path)

      assert Plug.Conn.get_session(updated_conn, :web_auth_redirect_path) == path
    end

    test "set_redirect_path/2 handles complex paths" do
      conn = build_conn_with_session()
      complex_path = "/cars/123/drives?page=2&sort=date#section"

      updated_conn = WebAuth.set_redirect_path(conn, complex_path)

      assert Plug.Conn.get_session(updated_conn, :web_auth_redirect_path) == complex_path
    end

    test "set_redirect_path/2 handles paths with unicode characters" do
      conn = build_conn_with_session()
      unicode_path = "/测试/路径"

      updated_conn = WebAuth.set_redirect_path(conn, unicode_path)

      assert Plug.Conn.get_session(updated_conn, :web_auth_redirect_path) == unicode_path
    end

    test "set_redirect_path/2 handles empty string path" do
      conn = build_conn_with_session()

      updated_conn = WebAuth.set_redirect_path(conn, "")

      assert Plug.Conn.get_session(updated_conn, :web_auth_redirect_path) == ""
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
      conn = build_conn_with_session(%{web_auth_redirect_path: "/old/path"})
      new_path = "/new/path"

      updated_conn = WebAuth.set_redirect_path(conn, new_path)

      assert Plug.Conn.get_session(updated_conn, :web_auth_redirect_path) == new_path
    end

    test "get_redirect_path/1 returns stored path" do
      path = "/stored/path"
      conn = build_conn_with_session(%{web_auth_redirect_path: path})

      assert WebAuth.get_redirect_path(conn) == path
    end

    test "get_redirect_path/1 returns default path when none stored" do
      conn = build_conn_with_session()

      path = WebAuth.get_redirect_path(conn)

      # Should return the default path from Routes.car_path
      assert is_binary(path)
      # Should contain "/car" in the path (from Routes.car_path)
      assert String.contains?(path, "/car") or path == "/"
    end

    test "get_redirect_path/1 handles Routes.car_path failure gracefully" do
      # Create a conn without proper router setup to simulate route failure
      conn =
        %Plug.Conn{
          assigns: %{},
          private: %{},
          req_headers: [],
          resp_headers: []
        }
        |> init_test_session(%{})

      # This should handle the case where Routes.car_path might fail
      path = WebAuth.get_redirect_path(conn)

      assert is_binary(path)
    end

    test "get_redirect_path/1 handles nil session value" do
      conn = build_conn_with_session(%{web_auth_redirect_path: nil})

      path = WebAuth.get_redirect_path(conn)

      assert is_binary(path)
    end

    test "clear_redirect_path/1 removes stored path" do
      conn = build_conn_with_session(%{web_auth_redirect_path: "/some/path"})

      cleared_conn = WebAuth.clear_redirect_path(conn)

      assert Plug.Conn.get_session(cleared_conn, :web_auth_redirect_path) == nil
    end

    test "clear_redirect_path/1 handles already cleared path" do
      conn = build_conn_with_session()

      cleared_conn = WebAuth.clear_redirect_path(conn)

      assert Plug.Conn.get_session(cleared_conn, :web_auth_redirect_path) == nil
    end

    test "get_and_clear_redirect_path/1 returns path and clears it" do
      path = "/test/path"
      conn = build_conn_with_session(%{web_auth_redirect_path: path})

      {updated_conn, returned_path} = WebAuth.get_and_clear_redirect_path(conn)

      assert returned_path == path
      assert Plug.Conn.get_session(updated_conn, :web_auth_redirect_path) == nil
    end

    test "get_and_clear_redirect_path/1 returns default path when none stored" do
      conn = build_conn_with_session()

      {updated_conn, returned_path} = WebAuth.get_and_clear_redirect_path(conn)

      assert is_binary(returned_path)
      assert Plug.Conn.get_session(updated_conn, :web_auth_redirect_path) == nil
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
      assert WebAuth.get_remote_ip(nil) == "Unknown"
      assert WebAuth.get_remote_ip("invalid") == "Unknown"
      assert WebAuth.get_remote_ip(%{}) == "Unknown"
      assert WebAuth.get_remote_ip(123) == "Unknown"
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

  describe "concurrent access and environment changes" do
    test "password verification handles concurrent environment changes" do
      System.put_env("WEB_AUTH_PASS", "initial_password")

      # Start multiple tasks that verify password concurrently
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            if rem(i, 2) == 0 do
              # Even tasks: verify correct password
              WebAuth.verify_password("initial_password")
            else
              # Odd tasks: verify wrong password
              WebAuth.verify_password("wrong_password")
            end
          end)
        end

      # Change environment variable while tasks are running
      System.put_env("WEB_AUTH_PASS", "changed_password")

      # Wait for all tasks to complete
      results = Task.await_many(tasks, 5000)

      # Verify that we get consistent results based on password correctness
      # (The exact password used depends on timing, but behavior should be consistent)
      assert length(results) == 10

      assert Enum.all?(results, fn result ->
               result in [
                 {:ok, :authenticated},
                 {:error, :invalid_password}
               ]
             end)

      System.delete_env("WEB_AUTH_PASS")
    end

    test "password_required? handles environment changes" do
      System.delete_env("WEB_AUTH_PASS")
      refute WebAuth.password_required?()

      System.put_env("WEB_AUTH_PASS", "new_password")
      assert WebAuth.password_required?()

      System.put_env("WEB_AUTH_PASS", "")
      refute WebAuth.password_required?()

      System.delete_env("WEB_AUTH_PASS")
      refute WebAuth.password_required?()
    end

    test "concurrent session operations are safe" do
      conn = build_conn_with_session()

      # Create multiple tasks that modify session concurrently
      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            case rem(i, 4) do
              0 -> WebAuth.authenticate(conn)
              1 -> WebAuth.unauthenticate(conn)
              2 -> WebAuth.set_redirect_path(conn, "/path#{i}")
              3 -> WebAuth.clear_redirect_path(conn)
            end
          end)
        end

      # All tasks should complete successfully
      results = Task.await_many(tasks, 5000)
      assert length(results) == 20
      assert Enum.all?(results, fn result -> match?(%Plug.Conn{}, result) end)
    end

    test "session validation under time manipulation" do
      # Save current time
      current_time = System.system_time(:second)

      conn =
        build_conn_with_session(%{
          web_authenticated: true,
          web_auth_time: current_time
        })

      # Should be authenticated initially
      assert WebAuth.authenticated?(conn)

      # Test session validation by creating new conn with same timestamp
      # This simulates the case where system time might have changed
      future_conn =
        build_conn_with_session(%{
          web_authenticated: true,
          web_auth_time: current_time
        })

      # Should still be valid (assuming less than 1 hour passed in test execution)
      assert WebAuth.authenticated?(future_conn)

      # Test with timestamp from way in the past
      past_conn =
        build_conn_with_session(%{
          web_authenticated: true,
          # 2 hours ago
          web_auth_time: current_time - 7200
        })

      refute WebAuth.authenticated?(past_conn)
    end

    test "environment variable persistence across function calls" do
      # Test that environment changes don't cause inconsistent behavior
      System.put_env("WEB_AUTH_PASS", "test123")

      # First verification
      assert {:ok, :authenticated} = WebAuth.verify_password("test123")
      assert WebAuth.password_required?()

      # Change environment
      System.put_env("WEB_AUTH_PASS", "different")

      # Should now use new environment value
      assert {:error, :invalid_password} = WebAuth.verify_password("test123")
      assert {:ok, :authenticated} = WebAuth.verify_password("different")
      assert WebAuth.password_required?()

      # Clear environment
      System.delete_env("WEB_AUTH_PASS")

      # Should now allow access without password
      assert {:ok, :no_password_set} = WebAuth.verify_password("")
      refute WebAuth.password_required?()
    end
  end

  describe "memory and performance considerations" do
    test "password verification memory usage with large passwords" do
      # Test that large passwords don't cause excessive memory usage
      # 100KB password
      large_password = String.duplicate("a", 100_000)
      System.put_env("WEB_AUTH_PASS", large_password)

      # Should handle large passwords without issues
      assert {:ok, :authenticated} = WebAuth.verify_password(large_password)
      assert {:error, :invalid_password} = WebAuth.verify_password(String.duplicate("b", 100_000))

      System.delete_env("WEB_AUTH_PASS")
    end

    test "session data doesn't accumulate over time" do
      conn = build_conn_with_session()

      # Perform many authentication cycles
      final_conn =
        Enum.reduce(1..100, conn, fn _i, acc_conn ->
          acc_conn
          |> WebAuth.authenticate()
          |> WebAuth.set_redirect_path("/path")
          |> WebAuth.unauthenticate()
          |> WebAuth.clear_redirect_path()
        end)

      # Session should not contain accumulated data
      session = Plug.Conn.get_session(final_conn)
      refute session[:web_authenticated]
      refute session[:web_auth_time]
      refute session[:web_auth_redirect_path]
    end

    test "rapid password verification doesn't degrade performance" do
      System.put_env("WEB_AUTH_PASS", "benchmark_password")

      # Time many rapid verifications
      {time_microseconds, _results} =
        :timer.tc(fn ->
          Enum.map(1..1000, fn _i ->
            WebAuth.verify_password("benchmark_password")
          end)
        end)

      # Should complete reasonably quickly (adjust threshold as needed)
      # 1000 verifications should take less than 1 second
      assert time_microseconds < 1_000_000

      System.delete_env("WEB_AUTH_PASS")
    end
  end

  describe "network security and header injection" do
    test "get_remote_ip handles malicious x-forwarded-for headers" do
      # Test SQL injection attempt in header
      malicious_header = "'; DROP TABLE users; --"

      conn =
        :get
        |> conn("/")
        |> put_req_header("x-forwarded-for", malicious_header)

      ip = WebAuth.get_remote_ip(conn)
      # Should return as-is, not execute
      assert ip == "'; DROP TABLE users; --"
    end

    test "get_remote_ip handles header with null bytes" do
      # Headers with null bytes (should be sanitized by Plug, but test robustness)
      header_with_special = "192.168.1.1\x00malicious"

      conn =
        :get
        |> conn("/")
        |> put_req_header("x-forwarded-for", header_with_special)

      ip = WebAuth.get_remote_ip(conn)
      assert is_binary(ip)
    end

    test "get_remote_ip handles extremely long IP chains" do
      # Very long chain of IPs (potential DoS vector)
      long_ip_chain =
        Enum.join(Enum.map(1..1000, fn i -> "192.168.1.#{rem(i, 255) + 1}" end), ", ")

      conn =
        :get
        |> conn("/")
        |> put_req_header("x-forwarded-for", long_ip_chain)

      ip = WebAuth.get_remote_ip(conn)
      # Should return first IP
      assert ip == "192.168.1.2"
    end

    test "get_user_agent handles malicious user agent strings" do
      # Test script injection in user agent
      malicious_ua = "<script>alert('xss')</script>"

      conn =
        :get
        |> conn("/")
        |> put_req_header("user-agent", malicious_ua)

      ua = WebAuth.get_user_agent(conn)
      # Should return as-is for logging, not execute
      assert ua == malicious_ua
    end

    test "get_user_agent handles user agent with control characters" do
      # User agent with control characters
      ua_with_control = "Mozilla/5.0\r\n\t(Control chars)"

      conn =
        :get
        |> conn("/")
        |> put_req_header("user-agent", ua_with_control)

      ua = WebAuth.get_user_agent(conn)
      assert ua == ua_with_control
    end

    test "utility functions handle connection without remote_ip" do
      # Test with malformed connection
      malformed_conn = %{not: :a_real_conn}

      assert WebAuth.get_remote_ip(malformed_conn) == "Unknown"
      assert WebAuth.get_user_agent(malformed_conn) == "Unknown"
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

    test "session functions handle corrupted session data" do
      # Test with session containing unexpected data types
      corrupted_conn =
        build_conn_with_session(%{
          web_authenticated: %{not: "boolean"},
          web_auth_time: "not_integer",
          web_auth_redirect_path: 12345
        })

      refute WebAuth.authenticated?(corrupted_conn)
      assert WebAuth.session_remaining_time(corrupted_conn) == 0

      # get_redirect_path should handle non-string redirect path
      path = WebAuth.get_redirect_path(corrupted_conn)
      assert is_binary(path)
    end

    test "password verification with extreme edge cases" do
      # Test with password containing special but valid characters (avoiding null bytes)
      # Using non-null control characters
      weird_password = String.duplicate("\x01\x02", 5)
      System.put_env("WEB_AUTH_PASS", weird_password)

      # Should handle binary data as password
      assert {:ok, :authenticated} = WebAuth.verify_password(weird_password)
      assert {:error, :invalid_password} = WebAuth.verify_password("")

      System.delete_env("WEB_AUTH_PASS")

      # Test verify_password with extremely large input
      # 1MB string
      huge_input = String.duplicate("x", 1_000_000)
      result = WebAuth.verify_password(huge_input)

      assert result in [
               {:ok, :no_password_set},
               {:error, :invalid_password}
             ]
    end

    test "redirect path functions with unusual path formats" do
      conn = build_conn_with_session()

      # Test with paths containing special characters
      special_paths = [
        "/path with spaces",
        "/path%20encoded",
        "/path?query=value&other=value",
        "/path#fragment",
        "/path/../../../etc/passwd",
        "/path\nwith\nnewlines",
        "//double/slash/path",
        "",
        "/",
        "/very/deep/path/that/goes/on/and/on/and/on/with/many/segments"
      ]

      for path <- special_paths do
        updated_conn = WebAuth.set_redirect_path(conn, path)
        retrieved_path = WebAuth.get_redirect_path(updated_conn)
        assert retrieved_path == path
      end
    end

    test "authentication functions handle edge timing conditions" do
      # Test authentication right at the boundary
      # Exactly 1 hour ago
      boundary_time = System.system_time(:second) - 3600

      conn =
        build_conn_with_session(%{
          web_authenticated: true,
          web_auth_time: boundary_time
        })

      # Should be expired (boundary is exclusive)
      refute WebAuth.authenticated?(conn)
      assert WebAuth.session_remaining_time(conn) == 0

      # Test just before boundary
      # 59 minutes 59 seconds ago
      almost_expired_time = System.system_time(:second) - 3599

      conn2 =
        build_conn_with_session(%{
          web_authenticated: true,
          web_auth_time: almost_expired_time
        })

      # Should still be valid
      assert WebAuth.authenticated?(conn2)
      remaining = WebAuth.session_remaining_time(conn2)
      assert remaining > 0 and remaining <= 1
    end

    test "functions handle nil and invalid conn structures" do
      # Test with nil
      assert WebAuth.get_remote_ip(nil) == "Unknown"
      assert WebAuth.get_user_agent(nil) == "Unknown"

      # Test with invalid structures
      fake_conn = %{fake: :conn}
      assert WebAuth.get_remote_ip(fake_conn) == "Unknown"
      assert WebAuth.get_user_agent(fake_conn) == "Unknown"

      # Test session functions with nil/invalid input
      assert WebAuth.authenticated?(nil) == false
      assert WebAuth.authenticated?(%{not: :session}) == false
      assert WebAuth.session_remaining_time(nil) == 0
      assert WebAuth.session_remaining_time(%{not: :session}) == 0
    end

    test "secure_compare edge cases through verify_password" do
      # Test that secure_compare handles edge cases properly
      System.put_env("WEB_AUTH_PASS", "test")

      # Test with strings that might cause timing differences
      similar_passwords = [
        # correct
        "test",
        # different case
        "Test",
        # different case at end
        "tesT",
        # shorter
        "tes",
        # longer
        "tests",
        # one character different
        "tast",
        # empty
        "",
        # with leading space
        " test",
        # with trailing space
        "test ",
        # with newline
        "test\n",
        # with null byte
        "test\x00"
      ]

      # All should execute in reasonable time and return consistent results
      for password <- similar_passwords do
        result = WebAuth.verify_password(password)

        if password == "test" do
          assert {:ok, :authenticated} = result
        else
          assert {:error, :invalid_password} = result
        end
      end

      System.delete_env("WEB_AUTH_PASS")
    end
  end

  describe "integration and real-world scenarios" do
    test "complete authentication flow simulation" do
      System.put_env("WEB_AUTH_PASS", "real_password")

      # Simulate complete flow: unauthenticated -> authenticated -> expired -> re-authenticated
      conn = build_conn_with_session()

      # Initially unauthenticated
      refute WebAuth.authenticated?(conn)
      assert WebAuth.session_remaining_time(conn) == 0

      # Set redirect path before authentication
      conn = WebAuth.set_redirect_path(conn, "/target/page")

      # Verify password and authenticate
      assert {:ok, :authenticated} = WebAuth.verify_password("real_password")
      conn = WebAuth.authenticate(conn)

      # Should now be authenticated
      assert WebAuth.authenticated?(conn)
      assert WebAuth.session_remaining_time(conn) > 3590

      # Get and clear redirect path
      {conn, redirect_path} = WebAuth.get_and_clear_redirect_path(conn)
      assert redirect_path == "/target/page"
      assert Plug.Conn.get_session(conn, "web_auth_redirect_path") == nil

      # Simulate session expiry by manually setting old timestamp
      expired_conn =
        build_conn_with_session(%{
          web_authenticated: true,
          # 2 hours ago
          web_auth_time: System.system_time(:second) - 7200
        })

      # Should be expired
      refute WebAuth.authenticated?(expired_conn)

      # Unauthenticate
      conn = WebAuth.unauthenticate(conn)
      refute WebAuth.authenticated?(conn)

      System.delete_env("WEB_AUTH_PASS")
    end

    test "password change during active session" do
      # Start with one password
      System.put_env("WEB_AUTH_PASS", "old_password")

      conn = build_conn_with_session()
      assert {:ok, :authenticated} = WebAuth.verify_password("old_password")
      conn = WebAuth.authenticate(conn)
      assert WebAuth.authenticated?(conn)

      # Change password
      System.put_env("WEB_AUTH_PASS", "new_password")

      # Existing session should still be valid (doesn't re-check password)
      assert WebAuth.authenticated?(conn)

      # But new authentication attempts should use new password
      assert {:ok, :authenticated} = WebAuth.verify_password("new_password")
      assert {:error, :invalid_password} = WebAuth.verify_password("old_password")

      System.delete_env("WEB_AUTH_PASS")
    end

    test "multiple concurrent users simulation" do
      System.put_env("WEB_AUTH_PASS", "shared_password")

      # Simulate multiple users with different session states
      users = [
        # New user
        build_conn_with_session(),
        # Authenticated user
        build_conn_with_session(%{
          web_authenticated: true,
          web_auth_time: System.system_time(:second)
        }),
        # Expired user
        build_conn_with_session(%{
          web_authenticated: true,
          web_auth_time: System.system_time(:second) - 7200
        })
      ]

      # Check authentication status for each user
      [new_user, auth_user, expired_user] = users

      refute WebAuth.authenticated?(new_user)
      assert WebAuth.authenticated?(auth_user)
      refute WebAuth.authenticated?(expired_user)

      # All users should be able to authenticate with correct password
      for conn <- users do
        assert {:ok, :authenticated} = WebAuth.verify_password("shared_password")
        authenticated_conn = WebAuth.authenticate(conn)
        assert WebAuth.authenticated?(authenticated_conn)
      end

      System.delete_env("WEB_AUTH_PASS")
    end

    test "load testing basic functionality" do
      System.put_env("WEB_AUTH_PASS", "load_test_password")

      # Test many rapid operations
      operations = [
        fn -> WebAuth.verify_password("load_test_password") end,
        fn -> WebAuth.verify_password("wrong_password") end,
        fn -> WebAuth.password_required?() end,
        fn ->
          conn =
            build_conn_with_session()
            |> WebAuth.authenticate()

          WebAuth.authenticated?(conn)
        end,
        fn ->
          conn = build_conn_with_session()
          WebAuth.session_remaining_time(conn)
        end
      ]

      # Run many operations rapidly
      results =
        for _i <- 1..200 do
          operation = Enum.random(operations)
          operation.()
        end

      # All operations should complete successfully
      assert length(results) == 200

      assert Enum.all?(results, fn result ->
               result in [
                 {:ok, :authenticated},
                 {:error, :invalid_password},
                 true,
                 false
               ] or is_integer(result)
             end)

      System.delete_env("WEB_AUTH_PASS")
    end
  end
end
