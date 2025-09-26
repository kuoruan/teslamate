defmodule TeslaMate.WebAuth do
  @moduledoc """
  Web 访问认证模块，用于保护 Web 界面不被未授权用户访问
  """

  require Logger

  alias TeslaMateWeb.Router.Helpers, as: Routes

  @session_timeout_hours 1
  @dummy_password "dummy"

  @doc """
  验证 Web 访问密码

  ## 返回值
  - `{:ok, :authenticated}` - 密码正确，认证成功
  - `{:ok, :no_password_set}` - 未设置密码，允许访问
  - `{:error, :invalid_password}` - 密码错误
  - `{:error, :invalid_input}` - 输入格式无效
  """
  def verify_password(password) when is_binary(password) do
    expected_password = get_password()

    case expected_password do
      nil ->
        # 执行假的密码比较以防止时序攻击
        secure_compare(password, @dummy_password)
        if password == "" do
          {:ok, :no_password_set}
        else
          {:error, :invalid_password}
        end

      "" ->
        secure_compare(password, @dummy_password)
        {:ok, :no_password_set}

      expected ->
        if secure_compare(password, expected) do
          {:ok, :authenticated}
        else
          {:error, :invalid_password}
        end
    end
  end

  def verify_password(_), do: {:error, :invalid_input}

  @doc """
  检查是否设置了密码
  """
  def password_required?() do
    pwd = get_password()

    is_binary(pwd) and pwd != ""
  end

  @doc """
  检查用户是否通过认证且会话仍然有效
  """
  def authenticated?(conn) do
    case {Plug.Conn.get_session(conn, :web_authenticated), Plug.Conn.get_session(conn, :web_auth_time)} do
      {true, auth_time} when is_integer(auth_time) -> session_valid?(auth_time)
      _ -> false
    end
  end

  @doc """
  标记用户为已认证，设置会话时间戳
  """
  def authenticate(conn) do
    conn
    |> Plug.Conn.put_session(:web_authenticated, true)
    |> Plug.Conn.put_session(:web_auth_time, System.system_time(:second))
  end

  @doc """
  清除用户认证状态
  """
  def unauthenticate(conn) do
    conn
    |> Plug.Conn.delete_session(:web_authenticated)
    |> Plug.Conn.delete_session(:web_auth_time)
  end

  @doc """
  获取会话剩余时间（秒）
  """
  def session_remaining_time(conn) do
    case Plug.Conn.get_session(conn, :web_auth_time) do
      nil -> 0
      auth_time -> max(0, auth_time + @session_timeout_hours * 3600 - System.system_time(:second))
    end
  end

  # 私有辅助函数

  defp get_password() do
    System.get_env("WEB_AUTH_PASS")
  end

  # 常时比较算法防止时序攻击
  defp secure_compare(left, right) when is_binary(left) and is_binary(right) do
    :crypto.hash_equals(left, right)
  end

  defp secure_compare(_, _), do: false

  # 会话有效性检查
  defp session_valid?(auth_time) when is_integer(auth_time) do
    System.system_time(:second) - auth_time < @session_timeout_hours * 3600
  end

  defp session_valid?(_), do: false

  @doc """
  获取客户端真实 IP 地址
  """
  def get_remote_ip(%Plug.Conn{} = conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> ip |> String.split(",") |> hd() |> String.trim()
      _ -> to_string(:inet.ntoa(conn.remote_ip))
    end
  end

  def get_remote_ip(_), do: "unknown"

  @doc """
  获取客户端用户代理信息
  """
  def get_user_agent(conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      [user_agent | _] -> user_agent
      _ -> "unknown"
    end
  end

  @doc """
  设置认证后重定向路径
  """
  def set_redirect_path(conn, path) when is_binary(path) do
    Plug.Conn.put_session(conn, :redirect_after_auth, path)
  end

  def set_redirect_path(conn, _), do: conn

  @doc """
  获取认证后重定向路径
  """
  def get_redirect_path(conn) do
    case Plug.Conn.get_session(conn, :redirect_after_auth) do
      path when is_binary(path) -> path
      _ -> default_redirect_path(conn)
    end
  end

  @doc """
  清除认证后重定向路径
  """
  def clear_redirect_path(conn) do
    Plug.Conn.delete_session(conn, :redirect_after_auth)
  end

  @doc """
  获取认证后重定向路径并清除
  """
  def get_and_clear_redirect_path(conn) do
    path = get_redirect_path(conn)
    conn = clear_redirect_path(conn)
    {conn, path}
  end

  # 默认重定向路径
  defp default_redirect_path(conn) do
    try do
      Routes.car_path(conn, :index)
    rescue
      _ -> "/"
    end
  end
end
