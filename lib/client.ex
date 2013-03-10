defmodule Genomu.Client do

  defmacro __using__(_) do
    quote do
      require Genomu.Client
    end
  end

  def connect(options) do
    :supervisor.start_child(Genomu.Client.Sup.Connections, [options])
  end

  def begin(conn, _options // []) do
    Genomu.Client.Connection.start_channel(conn)
  end

  def transaction(conn, f, options // []) when is_function(f, 1) do
    {:ok, ch} = begin(conn, options)
    try do
      result = f.(ch)
      :ok = commit(ch)
      result
    catch _, _ ->
      # TODO: rollback
      :ok
    end
  end

  defmacro execute(conn, ch, [do: body]) do
    quote do
      Genomu.Client.transaction(unquote(conn), fn(unquote(ch)) -> unquote(body) end)
    end
  end

  defdelegate [get(channel, addr, operation, options),
               get(channel, addr, operation),
               set(channel, addr, operation, options),
               set(channel, addr, operation),
               apply(channel, addr, operation, options),
               apply(channel, addr, operation),
               commit(channel), discard(channel)], to: Genomu.Client.Channel
end