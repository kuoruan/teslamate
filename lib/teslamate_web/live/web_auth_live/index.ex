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
        password: ""
      }

      {:ok, assign(socket, assigns)}
    end
  end

  @impl true
  def handle_event("change", %{"password" => password}, socket) do
    {:noreply, assign(socket, password: password)}
  end
end
