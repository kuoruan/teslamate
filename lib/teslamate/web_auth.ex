defmodule TeslaMate.WebAuth do
  @moduledoc """
  Web 访问认证模块，用于保护 Web 界面不被未授权用户访问
  """

  require Logger

  @doc """
  验证 Web 访问密码
  """
  def verify_password(password) when is_binary(password) do
    expected_password = get_web_password()

    case expected_password do
      nil ->
        # 如果没有设置密码，允许访问
        if password == "" do
          {:ok, :no_password_set}
        else
          {:error, :invalid_password}
        end

      expected when is_binary(expected) ->
        if password == expected do
          {:ok, :authenticated}
        else
          {:error, :invalid_password}
        end

      _ ->
        {:error, :invalid_password}
    end
  end

  def verify_password(_), do: {:error, :invalid_password}

  @doc """
  检查是否设置了密码
  """
  def password_required?() do
    case get_web_password() do
      nil -> false
      "" -> false
      _ -> true
    end
  end

  @doc """
  检查用户是否通过认证
  """
  def authenticated?(conn) do
    case Plug.Conn.get_session(conn, :web_authenticated) do
      true -> true
      _ -> false
    end
  end

  @doc """
  标记用户为已认证
  """
  def authenticate(conn) do
    Plug.Conn.put_session(conn, :web_authenticated, true)
  end

  @doc """
  标记用户为未认证
  """
  def unauthenticate(conn) do
    Plug.Conn.put_session(conn, :web_authenticated, false)
  end

  defp get_web_password() do
    System.get_env("WEB_PASS")
  end
end
