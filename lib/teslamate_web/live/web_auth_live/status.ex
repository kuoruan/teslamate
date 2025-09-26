defmodule TeslaMateWeb.WebAuthLive.Status do
  use TeslaMateWeb, :live_view

  alias TeslaMate.WebAuth

  on_mount {TeslaMateWeb.InitAssigns, :locale}

  @impl true
  def mount(_params, _session, socket) do
    # 检查是否需要密码认证
    if not WebAuth.password_required?() do
      {:ok, redirect(socket, to: Routes.car_path(socket, :index))}
    else
      # 只有已认证用户才能查看状态页面
      if WebAuth.authenticated?(socket) do
        remaining = WebAuth.session_remaining_time(socket)

        assigns = %{
          page_title: gettext("Authentication Status"),
          session_remaining: remaining,
          session_remaining_formatted: format_time_remaining(remaining),
          refresh_timer: nil,
          last_updated: DateTime.utc_now(),
          refreshing: false
        }

        socket = assign(socket, assigns)

        {:ok, socket}
      else
        {:ok, redirect(socket, to: auth_page(socket))}
      end
    end
  end

  @impl true
  def handle_event("refresh_session", _params, socket) do
    # 手动刷新会话
    socket = assign(socket, refreshing: true)

    authenticated_socket = WebAuth.authenticate(socket)
    remaining = WebAuth.session_remaining_time(authenticated_socket)

    socket =
      authenticated_socket
      |> assign(
        session_remaining: remaining,
        session_remaining_formatted: format_time_remaining(remaining),
        last_updated: DateTime.utc_now(),
        refreshing: false
      )
      |> put_flash(:success, gettext("Session refreshed successfully"))

    {:noreply, socket}
  end

  @impl true
  def handle_event("logout", _params, socket) do
    socket =
      socket
      |> WebAuth.unauthenticate()
      |> put_flash(:success, gettext("Successfully logged out"))
      |> redirect(to: auth_page(socket))

    {:noreply, socket}
  end

  defp format_time_remaining(seconds) when seconds <= 0, do: gettext("Expired")

  defp format_time_remaining(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    remaining_seconds = rem(seconds, 60)

    cond do
      hours > 0 and minutes > 0 ->
        "#{ngettext("%{count} hour", "%{count} hours", hours, count: hours)} #{ngettext("%{count} minute", "%{count} minutes", minutes, count: minutes)}"

      hours > 0 ->
        ngettext("%{count} hour", "%{count} hours", hours, count: hours)

      minutes > 0 ->
        ngettext("%{count} minute", "%{count} minutes", minutes, count: minutes)

      remaining_seconds > 0 ->
        ngettext("%{count} second", "%{count} seconds", remaining_seconds, count: remaining_seconds)

      true ->
        gettext("Expired")
    end
  end

  defp auth_page(socket), do: Routes.live_path(socket, TeslaMateWeb.WebAuthLive.Index)
end
