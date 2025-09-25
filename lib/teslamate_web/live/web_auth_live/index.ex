defmodule TeslaMateWeb.WebAuthLive.Index do
  use TeslaMateWeb, :live_view

  alias TeslaMate.WebAuth

  on_mount {TeslaMateWeb.InitAssigns, :locale}

  @impl true
  def mount(_params, _session, socket) do
    # 如果不需要密码，直接重定向到默认路径
    if not WebAuth.password_required?() do
      {:ok, redirect(socket, to: Routes.car_path(socket, :index))}
    else
      assigns = %{
        page_title: gettext("Web Access Authentication"),
        password: "",
        password_error: nil
      }

      {:ok, assign(socket, assigns)}
    end
  end

  @impl true
  def handle_event("validate", %{"password" => password}, socket) do
    password_error =
      case password do
        "" ->
          gettext("Password is required")

        p when is_binary(p) ->
          if String.trim(p) == "", do: gettext("Password is required"), else: nil

        _ ->
          gettext("Password is required")
      end

    {:noreply, assign(socket, password: password, password_error: password_error)}
  end
end
