defmodule Genomu.Client do
  def connect(options) do
    :supervisor.start_child(Genomu.Client.Sup.Connections, [options])
  end

  def begin(conn, _options // []) do
    Genomu.Client.Connection.start_channel(conn)
  end

  def commit(channel, _options // []) do
    Genomu.Client.Channel.commit(channel)
  end
end