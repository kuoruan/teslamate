defmodule TeslaMate.WebAuthTest do
  use ExUnit.Case, async: true

  alias TeslaMate.WebAuth

  describe "secure_compare/2" do
    test "returns true for identical strings" do
      # 使用反射访问私有函数进行测试
      assert apply(WebAuth, :secure_compare, ["password123", "password123"])
    end

    test "returns false for different strings" do
      refute apply(WebAuth, :secure_compare, ["password123", "wrongpass"])
    end

    test "returns false for different length strings" do
      refute apply(WebAuth, :secure_compare, ["short", "much_longer_password"])
    end

    test "handles empty strings correctly" do
      assert apply(WebAuth, :secure_compare, ["", ""])
      refute apply(WebAuth, :secure_compare, ["", "nonempty"])
    end
  end

  describe "verify_password/2" do
    test "succeeds with correct password" do
      System.put_env("WEB_PASS", "test_password")

      assert {:ok, :authenticated} = WebAuth.verify_password("test_password", "127.0.0.1")

      System.delete_env("WEB_PASS")
    end

    test "fails with incorrect password" do
      System.put_env("WEB_PASS", "test_password")

      assert {:error, :invalid_password} = WebAuth.verify_password("wrong_password", "127.0.0.1")

      System.delete_env("WEB_PASS")
    end

    test "allows access when no password is set" do
      System.delete_env("WEB_PASS")

      assert {:ok, :no_password_set} = WebAuth.verify_password("", "127.0.0.1")
    end

    test "rejects invalid input types" do
      assert {:error, :invalid_input} = WebAuth.verify_password(123, "127.0.0.1")
      assert {:error, :invalid_input} = WebAuth.verify_password(nil, "127.0.0.1")
    end
  end

  describe "password_required?/0" do
    test "returns false when no password is set" do
      System.delete_env("WEB_PASS")

      refute WebAuth.password_required?()
    end

    test "returns false when password is empty string" do
      System.put_env("WEB_PASS", "")

      refute WebAuth.password_required?()

      System.delete_env("WEB_PASS")
    end

    test "returns true when valid password is set" do
      System.put_env("WEB_PASS", "valid_password")

      assert WebAuth.password_required?()

      System.delete_env("WEB_PASS")
    end
  end

  describe "rate limiting" do
    test "locks account after too many failed attempts" do
      System.put_env("WEB_PASS", "correct_password")
      ip = "192.168.1.100"

      # 进行多次失败尝试
      for _i <- 1..6 do
        WebAuth.verify_password("wrong_password", ip)
      end

      # 应该被锁定
      assert {:error, :account_locked} = WebAuth.verify_password("wrong_password", ip)

      # 即使密码正确也应该被锁定
      assert {:error, :account_locked} = WebAuth.verify_password("correct_password", ip)

      System.delete_env("WEB_PASS")
    end
  end
end
