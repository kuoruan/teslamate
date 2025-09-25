defmodule TeslaMateWeb.WebAuthLive.Status do
  use TeslaMateWeb, :live_view

  alias TeslaMate.WebAuth

  on_mount {TeslaMateWeb.InitAssigns, :locale}

  @impl true
  def mount(_params, _session, socket) do
    # 只有已认证用户才能查看状态页面
    if WebAuth.authenticated?(socket) do
      assigns = %{
        page_title: gettext("Authentication Status"),
        session_remaining: WebAuth.session_remaining_time(socket),
        refresh_timer: nil
      }

      socket = assign(socket, assigns)

      # 每分钟刷新一次会话剩余时间
      if connected?(socket) do
        :timer.send_interval(60_000, self(), :update_session_info)
      end

      {:ok, socket}
    else
      {:ok, redirect(socket, to: Routes.car_path(socket, :index))}
    end
  end

  @impl true
  def handle_info(:update_session_info, socket) do
    remaining = WebAuth.session_remaining_time(socket)

    if remaining > 0 do
      {:noreply, assign(socket, session_remaining: remaining)}
    else
      # 会话已过期，重定向到登录页面
      {:noreply, redirect(socket, to: Routes.live_path(socket, TeslaMateWeb.WebAuthLive.Index))}
    end
  end

  @impl true
  def handle_event("refresh_session", _params, socket) do
    # 手动刷新会话
    socket =
      socket
      |> WebAuth.authenticate()
      |> assign(:session_remaining, WebAuth.session_remaining_time(socket))
      |> put_flash(:info, gettext("Session refreshed successfully"))

    {:noreply, socket}
  end

  defp format_time_remaining(seconds) when seconds <= 0, do: gettext("Expired")
  defp format_time_remaining(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)

    cond do
      hours > 0 -> ngettext("%{count} hour", "%{count} hours", hours, count: hours)
      minutes > 0 -> ngettext("%{count} minute", "%{count} minutes", minutes, count: minutes)
      true -> gettext("Less than a minute")
    end
  end
end
