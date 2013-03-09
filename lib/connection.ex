defmodule Genomu.Client.Connection do
  use GenServer.Behaviour

  def start_link(options) do
    :gen_server.start_link(__MODULE__, options, [])
  end

  defrecord State, host: nil, port: 9101, next_channel: 0, socket: nil, channels: nil

  @doc false
  def init(options) do
    channels = :ets.new(__MODULE__.Channels, [:ordered_set])
    state = State.new(options).channels(channels)
    :gen_server.cast(self, :connect)
    {:ok, state}
  end

  def start_channel(server) do
    :gen_server.call(server, :start_channel)
  end

  def send(server, binary) do
    :gen_server.cast(server, {:send, binary})
  end

  def handle_call(:start_channel, _from, State[socket: socket, next_channel: ch, channels: channels] = state) do
    channel = MsgPack.pack(ch)
    options = MsgPack.pack([])
    :gen_tcp.send(socket, channel <> options)
    state = state.update_next_channel(&1 + 1)
    {:ok, pid} = Genomu.Client.Channel.start(connection: self, channel: channel)
    :ets.insert(channels, [{pid, channel},{channel, pid}])
    {:reply, {:ok, pid}, state}
  end

  def handle_cast({:send, binary}, State[socket: socket] = state) do
    :gen_tcp.send(socket, binary)
    {:noreply, state}
  end

  def handle_cast(:connect, State[host: host, port: port] = state) do
    {:ok, socket} = :gen_tcp.connect(host |> to_char_list, port,
                                     [:binary, {:packet, 4}, {:active, true}])
    state = state.socket(socket)
    {:noreply, state}
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


end