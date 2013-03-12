defmodule Genomu.API do
 
  modules_dir = Path.expand("priv/modules", Genomu.Client.Mixfile.genomu_path)
 
  lc file inlist Path.wildcard(Path.join(modules_dir, "*.json")) do
    module = :jsx.to_term(File.read!(file), labels: :atom)

    ops = lc operation inlist module[:operations] do
      doc = if operation[:doc] == :null, do: nil, else: operation[:doc]
      if operation[:args] == 0 do
        args = []
      else
        args = Enum.map(1..operation[:args], fn(n) -> (quote do: var!(unquote(:"arg_#{n}"))) end)
      end
      name = binary_to_atom(operation[:name])
      def decode(<< unquote_splicing(binary_to_list(MsgPack.pack(module[:id]) <>
                                                    MsgPack.pack(operation[:id]))),
                    arg :: binary >>) do
        { arg, _ } = MsgPack.unpack(arg)
        unless is_list(arg), do: arg = [arg]
        { Module.concat([__MODULE__, String.capitalize(unquote(module[:name]))]), unquote(name), arg }
      end
      quote do
        @doc unquote(doc)
        def unquote(name)(unquote_splicing(args)) do
          MsgPack.pack(unquote(module[:id])) <>
          MsgPack.pack(unquote(operation[:id])) <>
          if unquote(operation[:args] == 1) do
            MsgPack.pack(unquote_splicing(args))
          else
            MsgPack.pack(unquote(args))
          end
        end
      end
    end

    quoted = quote do
                @moduledoc unquote(module[:doc])
                unquote_splicing(ops)
             end

    Module.create Module.concat([__MODULE__, String.capitalize(module[:name])]), quoted
  end

  def decode(_), do: nil
end