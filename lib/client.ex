defmodule Genomu.Client do
  def connect(options) do
    :supervisor.start_child(Genomu.Client.Sup.Connections, [options])
  end
end