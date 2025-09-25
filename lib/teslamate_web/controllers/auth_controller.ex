defmodule TeslaMateWeb.AuthController do
  use TeslaMateWeb, :controller

  alias TeslaMate.WebAuth

  require Logger

  @doc """
  处理认证请求

  验证密码并设置认证状态
  """
  def authenticate(conn, %{"password" => password}) do
    remote_ip = WebAuth.get_remote_ip(conn)

    {conn, redirect_path} = WebAuth.get_and_clear_redirect_path(conn)

    case WebAuth.verify_password(password) do
      {:ok, :authenticated} ->
        Logger.info("User authenticated successfully", remote_ip: remote_ip)

        conn
        |> WebAuth.authenticate()
        |> put_flash(:info, gettext("Successfully authenticated"))
        |> redirect(to: redirect_path)

      {:ok, :no_password_set} ->
        Logger.info("No password set, allowing access", remote_ip: remote_ip)
        redirect(conn, to: redirect_path)

      {:error, :invalid_password} ->
        Logger.warning("Invalid password attempt", remote_ip: remote_ip)

        conn
        |> put_flash(:error, gettext("Invalid password"))
        |> redirect(to: auth_page(conn))

      {:error, :invalid_input} ->
        Logger.warning("Invalid input format", remote_ip: remote_ip)

        conn
        |> put_flash(:error, gettext("Invalid input format"))
        |> redirect(to: auth_page(conn))

      {:error, :invalid_encoding} ->
        Logger.warning("Invalid password encoding", remote_ip: remote_ip)

        conn
        |> put_flash(:error, gettext("Invalid password format"))
        |> redirect(to: auth_page(conn))

      {:error, reason} ->
        Logger.error("Authentication error", reason: reason, remote_ip: remote_ip)

        conn
        |> put_flash(:error, gettext("Authentication failed. Please try again."))
        |> redirect(to: auth_page(conn))
    end
  end

  # 处理缺少密码参数的情况
  def authenticate(conn, _params) do
    Logger.warning("Authentication attempt without password parameter")

    conn
    |> put_flash(:error, gettext("Password is required"))
    |> redirect(to: auth_page(conn))
  end

  @doc """
  用户登出

  清除认证状态并重定向到登录页面
  """
  def logout(conn, _params) do
    Logger.info("User logout")

    conn
    |> WebAuth.unauthenticate()
    |> put_flash(:info, gettext("Successfully logged out"))
    |> redirect(to: auth_page(conn))
  end

  # 私有辅助函数

  defp auth_page(conn), do: Routes.live_path(conn, TeslaMateWeb.WebAuthLive.Index)
end
