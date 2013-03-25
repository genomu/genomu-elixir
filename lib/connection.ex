defmodule Genomu.Client.Connection do
  use GenServer.Behaviour

  def start_link(options) do
    :gen_server.start_link(__MODULE__, options, [])
  end


  defrecord State, host: nil, port: 9101, next_channel: 0, socket: nil, channels: nil, retries: 10, left: 10, reconnect_timeout: 1000

  @doc false
  def init(options) do
    channels = :ets.new(__MODULE__.Channels, [:ordered_set])
    state = State.new(options).channels(channels)
    :gen_server.cast(self, :connect)
    {:ok, state}
  end

  def start_channel(server, options) do
    :gen_server.call(server, {:start_channel, options})
  end

  def start_watcher(server, fun, subscriptions) do
    :gen_server.call(server, {:start_watcher, fun, subscriptions})
  end

  def send(server, binary) do
    :gen_server.cast(server, {:send, binary})
  end

  def handle_call({:start_channel, options}, _from, State[socket: socket, next_channel: ch, channels: channels] = state) do
    channel = MsgPack.pack(ch)
    options = MsgPack.pack(encode_options(options, []))
    :gen_tcp.send(socket, channel <> options)
    state = state.update_next_channel(&1 + 1)
    {:ok, pid} = Genomu.Client.Channel.start(connection: self, channel: channel)
    :ets.insert(channels, [{pid, channel},{channel, pid}])
    {:reply, {:ok, pid}, state}
  end

  def handle_call({:start_watcher, fun, subscriptions}, _from, State[socket: socket, next_channel: ch, channels: channels] = state) do
    channel = MsgPack.pack(ch)
    subscriptions = MsgPack.pack(subscriptions)
    :gen_tcp.send(socket, channel <> subscriptions)
    state = state.update_next_channel(&1 + 1)
    ref = make_ref
    {:ok, pid} = Genomu.Client.Watcher.start(connection: self, channel: channel, fun: fun, ref: ref)
    :ets.insert(channels, [{pid, channel},{channel, pid}])
    {:reply, {:ok, pid, ref}, state}
  end


  def handle_cast({:send, binary}, State[socket: socket] = state) do
    :gen_tcp.send(socket, binary)
    {:noreply, state}
  end

  def handle_cast(:connect, state) do
    connect(state)
  end

  def handle_info({:tcp, socket, data}, State[socket: socket, channels: channels] = state) do
    {channel, rest} = MsgPack.next(data)
    case :ets.lookup(channels, channel) do
      [] -> :discard
      [{_, pid}] ->
        Genomu.Client.Channel.data(pid, rest)
    end
    {:noreply,state}
  end

  def handle_info({:tcp_closed, socket}, State[socket: socket] = state) do
    {:stop, :normal, state}
  end

  def handle_info(:timeout, State[socket: nil] = state) do
    connect(state)
  end

  defp connect(State[left: 0] = state), do: {:stop, :normal, state}
  defp connect(State[host: host, port: port, 
                     retries: retries, left: left, reconnect_timeout: timeout] = state) do
    connected = :gen_tcp.connect(host |> to_char_list, port,
       [:binary, {:packet, 4}, {:active, true}, {:nodelay, true}])
    case connected do
      {:ok, socket} -> 
         state = state.socket(socket)
         state = state.left(retries)
         {:noreply, state}
      {:error, :econnrefused} -> 
         state = state.left(left - 1)
         {:noreply, state, timeout}
    end
  end

    defmacro n, do: 0
    defmacro r, do: 1
    defmacro vnode, do: 2

  defp encode_options([], options), do: MsgPack.Map.from_list(options)
  defp encode_options([{:n, n}|t], options) do
    encode_options(t, [{0, n}|options])
  end
  defp encode_options([{:r, r}|t], options) do
    encode_options(t, [{1, r}|options])
  end
  defp encode_options([{:vnode, :all}|t], options) do
    encode_options(t, [{2, 0}|options])
  end
  defp encode_options([{:vnode, :primary}|t], options) do
    encode_options(t, [{2, 1}|options])
  end
  defp encode_options([{:timeout, timeout}|t], options) do
    encode_options(t, [{3, timeout}|options])
  end

end