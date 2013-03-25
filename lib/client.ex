defexception Genomu.Client.TimeoutException, message: "Timeout occured"
defexception Genomu.Client.AbortException, message: "Operation was aborted"

defmodule Genomu.Client do

  defmacro __using__(_) do
    quote do
      require Genomu.Client
    end
  end

  def connect(options) do
    :supervisor.start_child(Genomu.Client.Sup.Connections, [options])
  end

  def begin(conn, options // []) do
    Genomu.Client.Connection.start_channel(conn, options)
  end

  def watch(conn, fun, subscription) when is_binary(subscription) do
    watch(conn, fun, [subscription])
  end
  def watch(conn, fun, subscriptions) when is_list(subscriptions) do
    subscriptions = Enum.map(subscriptions, fn(s) when is_binary(s) -> [s]
                                              (s) -> s
                                            end)
    Genomu.Client.Connection.start_watcher(conn, fun, subscriptions)
  end

  def transaction(conn, f, options // []) when is_function(f, 1) do
    auto_commit = Keyword.get(options, :commit, true)
    options = Keyword.delete(options, :commit)
    {:ok, ch} = begin(conn, options)
    try do
      result = f.(ch)
      if auto_commit and Process.alive?(ch), do: :ok = commit(ch)
      result
    rescue e ->
      if Process.alive?(ch), do: discard(ch)
      raise e
    end
  end

  defp __transaction__(conn, ch, options) do
    body = options[:do]
    options = Keyword.delete(options, :do)
    quote do
      {:ok, unquote(ch)} = Genomu.Client.begin(unquote(conn), unquote(options))
      try do
        result = unquote(body)
        if Process.alive?(unquote(ch)), do: :ok = Genomu.Client.commit(unquote(ch))
        result
      rescue e ->
        if Process.alive?(unquote(ch)), do: Genomu.Client.discard(unquote(ch))
        raise e
      end
    end
  end

  defmacro execute(conn, ch, [do: _] = options) do
    __transaction__(conn, ch, options)
  end
  defmacro execute(conn, ch, options) do
    __transaction__(conn, ch, options)
  end

  defdelegate [get(channel, addr, operation, options),
               get(channel, addr, operation_or_options),
               get(channel, addr),
               set(channel, addr, operation, options),
               set(channel, addr, operation),
               apply(channel, addr, operation, options),
               apply(channel, addr, operation),
               commit(channel), discard(channel)], to: Genomu.Client.Channel
end