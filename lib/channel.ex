defmodule Genomu.Client.Channel do
  use GenServer.Behaviour

  def start(options) do
    :supervisor.start_child(Genomu.Client.Sup.Channels, [options])
  end

  def start_link(options) do
    :gen_server.start_link(__MODULE__, options, [])
  end

  defrecord State, connection: nil, channel: nil, reply_to: nil, req_options: []

  @doc false
  def init(options) do
    state = State.new(options)
    Process.link(state.connection)
    {:ok, state}
  end

  @get_value MsgPack.pack(0)
  @set_value MsgPack.pack(1)
  @apply_value MsgPack.pack(2)
  @true_value MsgPack.pack(true)

  alias Genomu.Client.Connection, as: Conn

  def data(server, data) do
    :gen_server.cast(server, {:data, data})
  end

  def get(server, addr, op, options // []) do
    :gen_server.call(server, {:send, addr, op, @get_value, options})
  end

  def set(server, addr, op, options // []) do
    :gen_server.call(server, {:send, addr, op, @set_value, options})
  end

  def apply(server, addr, op, options // []) do
    :gen_server.call(server, {:send, addr, op, @apply_value, options})
  end

  def commit(server) do
    result = :gen_server.call(server, :commit)
    :gen_server.cast(self, :stop)
    result
  end

  def handle_call({:send, addr, op, type, options}, from, State[connection: c, channel: ch] = state) do
    Conn.send(c, ch <> encode_addr(addr) <> type <> op)
    {:noreply, state.req_options(options).reply_to(from)}
  end

  def handle_call(:commit, from, State[connection: c, channel: ch] = state) do
    Conn.send(c, ch <> @true_value)
    {:noreply, state.reply_to(from)}
  end

  def handle_cast({:data, @true_value}, State[reply_to: from] = state) do
    :gen_server.reply(from, :ok)
    {:noreply, state}
  end

  def handle_cast({:data, data}, State[reply_to: from, req_options: opts] = state) do
    {value, rest} = MsgPack.unpack(data)
    case rest do
      "" -> response = value
      _ ->
        {clock, rest} = MsgPack.unpack(rest)
        {txn, ""} = MsgPack.unpack(rest)
        response =
        cond do
          (opts[:version] || false) and (opts[:txn] || false) ->
            {value, clock, txn}
          opts[:version] ->
            {value, clock}
          opts[:txn] ->
            {value, txn}
          true ->
            value
        end
    end
    :gen_server.reply(from, response)
    {:noreply, state}
  end

  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  defp encode_addr(key) when is_list(key) do
    MsgPack.pack(key)
  end
  defp encode_addr({key, rev}) do
    MsgPack.pack(MsgPack.Map.from_list([{0, [key, rev]}]))
  end

end