defmodule TeslaMateWeb.WebAuthController do
  use TeslaMateWeb, :controller

  alias TeslaMate.WebAuth

  require Logger

  @doc """
  处理认证请求

  验证密码并设置认证状态
  """
  def authenticate(conn, %{"password" => password}) do
    remote_ip = WebAuth.get_remote_ip(conn)

    case WebAuth.verify_password(password) do
      {:ok, :authenticated} ->
        Logger.info("User authenticated successfully, remote ip: #{remote_ip}")

        {conn, redirect_path} = WebAuth.get_and_clear_redirect_path(conn)

        conn
        |> WebAuth.authenticate()
        |> put_flash(:info, gettext("Successfully authenticated"))
        |> redirect(to: redirect_path)

      {:ok, :no_password_set} ->
        Logger.info("No password set, allowing access, remote ip: #{remote_ip}")
        redirect(conn, to: Routes.car_path(conn, :index))

      {:error, :invalid_password} ->
        Logger.warning("Invalid password attempt, remote ip: #{remote_ip}")

        conn
        |> put_flash(:warning, gettext("Invalid password"))
        |> redirect(to: auth_page(conn))

      {:error, :invalid_input} ->
        Logger.warning("Invalid input format, remote ip: #{remote_ip}")

        conn
        |> put_flash(:warning, gettext("Invalid input format"))
        |> redirect(to: auth_page(conn))

      {:error, reason} ->
        Logger.error("Authentication error, reason: #{reason}, remote ip: #{remote_ip}")

        conn
        |> put_flash(:warning, gettext("Authentication failed. Please try again."))
        |> redirect(to: auth_page(conn))
    end
  end

  # 处理缺少密码参数的情况
  def authenticate(conn, _params) do
    Logger.warning("Authentication attempt without password parameter")

    conn
    |> put_flash(:warning, gettext("Password is required"))
    |> redirect(to: auth_page(conn))
  end

  @doc """
  续期会话

  更新认证时间戳，延长会话有效期
  """
  def renew(conn, _params) do
    if WebAuth.authenticated?(conn) do
      Logger.info("Session renewed, remote ip: #{WebAuth.get_remote_ip(conn)}")

      conn
      # 重新设置认证时间戳
      |> WebAuth.authenticate()
      |> put_flash(:info, gettext("Session renewed successfully"))
      |> redirect(to: Routes.live_path(conn, TeslaMateWeb.WebAuthLive.Status))
    else
      Logger.warning("Unauthorized session renewal attempt",
        remote_ip: WebAuth.get_remote_ip(conn)
      )

      conn
      |> put_flash(:warning, gettext("Please login first"))
      |> redirect(to: auth_page(conn))
    end
  end

  @doc """
  用户登出

  清除认证状态并重定向到登录页面
  """
  def logout(conn, _params) do
    Logger.info("User logout, remote ip: #{WebAuth.get_remote_ip(conn)}")

    conn
    |> WebAuth.unauthenticate()
    |> put_flash(:info, gettext("Successfully logged out"))
    |> redirect(to: auth_page(conn))
  end

  defp auth_page(conn), do: Routes.live_path(conn, TeslaMateWeb.WebAuthLive.Index)
end
