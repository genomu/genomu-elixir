defmodule Genomu.Client.Watcher do
  use GenServer.Behaviour

  def start(options) do
    :supervisor.start_child(Genomu.Client.Sup.Watchers, [options])
  end

  def start_link(options) do
    :gen_server.start_link(__MODULE__, options, [])
  end

  defrecord State, connection: nil, channel: nil, fun: nil, ref: nil

  @doc false
  def init(options) do
    state = State.new(options)
    Process.link(state.connection)
    {:ok, state}
  end

  def stop(server) do
    :gen_server.cast(server, :stop)
  end


  @true_value MsgPack.pack(true)
  @false_value MsgPack.pack(false)
  @nil_value MsgPack.pack(nil)

  alias Genomu.Client.Connection, as: Conn

  def handle_cast({:data, data}, State[fun: fun, ref: ref] = state) do
    {subscription, rest} = MsgPack.unpack(data)
    {commit_object, ""} = MsgPack.unpack(rest)
    fun.(ref, subscription, commit_object)
    {:noreply, state}
  end

  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end


end