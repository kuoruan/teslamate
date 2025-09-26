defmodule TeslaMateWeb.Plugs.WebAuth do
  @moduledoc """
  Web访问认证中间件

  负责检查用户认证状态，处理会话超时，并在必要时重定向到认证页面。
  支持保存原始请求路径以便认证后重定向。
  """

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  alias TeslaMate.WebAuth
  alias TeslaMateWeb.Router.Helpers, as: Routes

  require Logger

  # 5分钟阈值
  @refresh_threshold 5 * 60

  def init(_options) do
    []
  end

  def call(conn, _options) do
    cond do
      # 如果不需要密码认证，直接通过
      not WebAuth.password_required?() ->
        conn

      # 检查用户认证状态
      WebAuth.authenticated?(conn) ->
        maybe_renew_session(conn)

      # 需要认证，保存原始路径并重定向
      true ->
        handle_unauthenticated_request(conn)
    end
  end

  # 处理未认证的请求
  defp handle_unauthenticated_request(conn) do
    # 保存原始请求路径（仅对 GET 请求）
    conn =
      if conn.method == "GET" and conn.request_path != "/" do
        WebAuth.set_redirect_path(conn, conn.request_path)
      else
        conn
      end

    # 记录未授权访问尝试
    Logger.info("Unauthorized access attempt", %{
      path: conn.request_path,
      method: conn.method,
      remote_ip: WebAuth.get_remote_ip(conn),
      user_agent: WebAuth.get_user_agent(conn)
    })

    conn
    |> redirect(to: Routes.live_path(conn, TeslaMateWeb.WebAuthLive.Index))
    |> halt()
  end

  # 在会话接近过期时刷新会话
  defp maybe_renew_session(conn) do
    remaining = WebAuth.session_remaining_time(conn)

    # 如果剩余时间少于配置的阈值，刷新会话
    if remaining > 0 and remaining < @refresh_threshold do
      WebAuth.authenticate(conn)
    else
      conn
    end
  end
end
