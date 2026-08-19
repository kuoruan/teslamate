defmodule TeslaMateWeb.Plugs.RateLimit do
  @moduledoc """
  基于 ETS 滑动窗口的简单请求限流。

  按 remote_ip 限制时间窗口内的请求数，超限返回 429。
  无外部依赖，ETS 表 `:teslamate_rate_limit` 在应用启动时创建。

  ## 用法

      plug TeslaMateWeb.Plugs.RateLimit, max: 60, window_ms: 60_000
  """

  import Plug.Conn

  @table :teslamate_rate_limit

  def init(opts) do
    %{
      max: Keyword.get(opts, :max, 60),
      window_ms: Keyword.get(opts, :window_ms, 60_000)
    }
  end

  def call(conn, %{max: max, window_ms: window_ms}) do
    key = conn.remote_ip

    now = System.monotonic_time(:millisecond)
    cutoff = now - window_ms

    timestamps =
      case :ets.lookup(@table, key) do
        [{^key, ts}] -> Enum.filter(ts, fn t -> t > cutoff end)
        [] -> []
      end

    if length(timestamps) >= max do
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(:too_many_requests, "Too Many Requests")
      |> halt()
    else
      :ets.insert(@table, {key, [now | timestamps]})
      conn
    end
  end

  @doc false
  def init_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:set, :public, :named_table])
    end
  end
end
