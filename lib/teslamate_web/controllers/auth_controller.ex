defmodule TeslaMateWeb.AuthController do
  use TeslaMateWeb, :controller

  alias TeslaMate.WebAuth

  @doc """
  认证页面
  """
  def authenticate(conn, %{"password" => password}) do
    case WebAuth.verify_password(password) do
      {:ok, :authenticated} ->
        conn
        |> WebAuth.authenticate()
        |> put_flash(:info, "Authenticated successfully")
        |> redirect(to: "/")

      {:ok, :no_password_set} ->
        redirect(conn, to: "/")

      {:error, :invalid_password} ->
        conn
        |> put_flash(:error, "Invalid password")
        |> redirect(to: "/web_auth")
    end
  end

  @doc """
  登出
  """
  def logout(conn, _params) do
    conn
    |> WebAuth.unauthenticate()
    |> put_flash(:info, "Logged out successfully")
    |> redirect(to: "/web_auth")
  end
end
