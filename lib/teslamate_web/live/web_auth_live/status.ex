defmodule TeslaMateWeb.WebAuthLive.Status do
  use TeslaMateWeb, :live_view

  alias TeslaMate.WebAuth

  on_mount {TeslaMateWeb.InitAssigns, :locale}

  @impl true
  def mount(_params, session, socket) do
    # 检查是否需要密码认证
    if not WebAuth.password_required?() do
      {:ok, redirect(socket, to: Routes.car_path(socket, :index))}
    else
      # 只有已认证用户才能查看状态页面
      if WebAuth.authenticated?(session) do
        auth_time = Map.get(session, "web_auth_time")
        remaining = WebAuth.session_remaining_time(session)

        assigns = %{
          page_title: gettext("Auth Status"),
          auth_time: auth_time,
          session_remaining: remaining,
          session_remaining_formatted: format_time_remaining(remaining),
          last_updated: DateTime.utc_now()
        }

        socket = assign(socket, assigns)

        if connected?(socket) do
          :timer.send_interval(60_000, :check_session)
        end

        {:ok, socket}
      else
        {:ok, redirect(socket, to: Routes.live_path(socket, TeslaMateWeb.WebAuthLive.Index))}
      end
    end
  end

  @impl true
  def handle_info(:check_session, socket) do
    # 会话过期则跳转登录页；auth_time 在 mount 时存入 assigns (非敏感时间戳)
    auth_time = socket.assigns[:auth_time]

    if WebAuth.authenticated?(auth_time) do
      remaining = WebAuth.session_remaining_time(auth_time)

      {:noreply,
       assign(socket,
         session_remaining: remaining,
         session_remaining_formatted: format_time_remaining(remaining),
         last_updated: DateTime.utc_now()
       )}
    else
      {:noreply,
       push_redirect(socket, to: Routes.live_path(socket, TeslaMateWeb.WebAuthLive.Index))}
    end
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
        ngettext("%{count} second", "%{count} seconds", remaining_seconds,
          count: remaining_seconds
        )

      true ->
        gettext("Expired")
    end
  end
end
