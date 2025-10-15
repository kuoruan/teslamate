defmodule TeslaMateWeb.Plugs.ApiAuth do
  @moduledoc """
  API访问认证中间件

  负责检查API请求的认证状态，支持以下认证方式：
  1. Basic Auth - 优先级最高，通过 Authorization header 传输
  2. Session Auth - 如果存在有效会话则使用会话认证

  认证失败时返回适当的HTTP状态码和JSON错误消息。
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias TeslaMate.WebAuth

  require Logger

  def init(_options) do
    []
  end

  def call(conn, _options) do
    cond do
      # 如果不需要密码认证，直接通过
      not WebAuth.password_required?() ->
        conn

      # 尝试Basic Auth认证（优先级最高）
      basic_auth_credentials = get_basic_auth_credentials(conn) ->
        handle_basic_auth(conn, basic_auth_credentials)

      # 尝试Session认证
      WebAuth.authenticated?(conn) ->
        log_auth_success(conn, "session_auth")
        conn

      # 认证失败
      true ->
        handle_unauthenticated_request(conn)
    end
  end

  # 获取Basic Auth凭据
  defp get_basic_auth_credentials(conn) do
    case get_req_header(conn, "authorization") do
      ["Basic " <> encoded] ->
        case Base.decode64(encoded) do
          {:ok, decoded} ->
            case String.split(decoded, ":", parts: 2) do
              [_username, password] -> password
              _ -> nil
            end

          :error ->
            nil
        end

      _ ->
        nil
    end
  end

  # 处理Basic Auth认证
  defp handle_basic_auth(conn, password) do
    case WebAuth.verify_password(password) do
      {:ok, :authenticated} ->
        log_auth_success(conn, "basic_auth")
        conn

      {:ok, :no_password_set} ->
        log_auth_success(conn, "basic_auth_no_password")
        conn

      {:error, reason} ->
        log_auth_failure(conn, "basic_auth", reason)
        handle_auth_error(conn, reason)
    end
  end

  # 处理未认证的请求
  defp handle_unauthenticated_request(conn) do
    log_auth_failure(conn, "no_auth", :missing_credentials)
    handle_auth_error(conn, :missing_credentials)
  end

  # 处理认证错误
  defp handle_auth_error(conn, reason) do
    {status, message} = get_error_response(reason)

    conn
    |> put_status(status)
    |> put_resp_header("www-authenticate", "Basic realm=\"TeslaMate API\"")
    |> json(%{
      error: "authentication_failed",
      message: message,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
    |> halt()
  end

  # 获取错误响应
  defp get_error_response(:invalid_password), do: {:unauthorized, "Invalid credentials"}
  defp get_error_response(:invalid_input), do: {:bad_request, "Invalid authentication format"}
  defp get_error_response(:missing_credentials), do: {:unauthorized, "Authentication required"}
  defp get_error_response(_), do: {:unauthorized, "Authentication failed"}

  # 记录认证成功
  defp log_auth_success(conn, method) do
    info = %{
      method: method,
      path: conn.request_path,
      remote_ip: WebAuth.get_remote_ip(conn),
      user_agent: WebAuth.get_user_agent(conn)
    }

    Logger.info("API authentication successful, #{inspect(info, pretty: true)}")
  end

  # 记录认证失败
  defp log_auth_failure(conn, method, reason) do
    info = %{
      method: method,
      reason: reason,
      path: conn.request_path,
      remote_ip: WebAuth.get_remote_ip(conn),
      user_agent: WebAuth.get_user_agent(conn)
    }

    Logger.info("API authentication failed, #{inspect(info, pretty: true)}")
  end
end
