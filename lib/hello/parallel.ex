defmodule Project4 do
  use GenServer

  import Transaction
  import Blockchain

  def no_of_blocks() do
    blockchain = :ets.lookup(:table78, :blockchain) |> Keyword.get(:blockchain)
    noblist = :ets.lookup(:table78, :noblist) |> Keyword.get(:noblist)
    noblist = noblist ++ [length(blockchain.chain)]
    t = :ets.insert(:table78, {:noblist, noblist})
    x = noblist
    y = Enum.with_index(x, 1)

    Enum.map(y, fn {a, b} -> [b, a] end)
  end

  def total_amount_transacted() do
    blockchain = :ets.lookup(:table78, :blockchain) |> Keyword.get(:blockchain)
    tatlist = :ets.lookup(:table78, :tatlist) |> Keyword.get(:tatlist)
    tatlist = tatlist ++ [(length(blockchain.chain) - 2) * 110]
    z = :ets.insert(:table78, {:tatlist, tatlist})
    x = tatlist
    y = Enum.with_index(x, 1)

    Enum.map(y, fn {a, b} -> [b, a] end)
  end

  def tm() do
    blockchain = :ets.lookup(:table78, :blockchain) |> Keyword.get(:blockchain)

    (length(blockchain.chain) - 2) * 110
  end

  def total_miningrewards() do
    blockchain = :ets.lookup(:table78, :blockchain) |> Keyword.get(:blockchain)
    y = (length(blockchain.chain) - 2) * 100
    y
  end

  def node_balance() do
    blockchain = :ets.lookup(:table78, :blockchain) |> Keyword.get(:blockchain)
    node_collection = :ets.lookup(:table78, :node_collection) |> Keyword.get(:node_collection)

    x =
      Enum.map(1..99, fn p ->
        get_balance(blockchain, getwallet_address(Enum.at(node_collection, p)))
      end)
  end

  def getdata do
    blockchain = :ets.lookup(:table78, :blockchain) |> Keyword.get(:blockchain)
    blocks = blockchain.chain

    completed_txns =
      Enum.reduce(blocks, [], fn block, acc ->
        if block.transactions != nil do
          Enum.concat(acc, block.transactions)
        else
          acc
        end
      end)

    pending_txns = blockchain.pending_txns
    {pending_txns, length(completed_txns)}
  end

  def test do
    b = :ets.lookup(:table78, :blockchain) |> Keyword.get(:blockchain)
    length(b.chain)
  end

  def main() do
    node_collection =
      Enum.map(1..100, fn i ->
        pid = new_node()
        pid
      end)

    table78 = :ets.new(:table78, [:named_table, :public])
    x = :ets.insert(table78, {:noblist, [0]})
    x = :ets.insert(:table78, {:blockchain, []})
    x = :ets.insert(:table78, {:length, 1})
    x = :ets.insert(table78, {:node_collection, [node_collection]})
    x = :ets.insert(table78, {:tatlist, [0]})
    blockchain = genesis_block()
    x = :ets.insert(:table78, {:blockchain, blockchain})
    # giving node 0 a balance of 100
    block = mining_pending_txns(blockchain, getwallet_address(Enum.at(node_collection, 0)))
    blockchain = %{blockchain | chain: blockchain.chain ++ [block]}
    blockchain = %{blockchain | pending_txns: []}
    x = :ets.insert(:table78, {:blockchain, blockchain})
    blockchain = :ets.lookup(:table78, :blockchain) |> Keyword.get(:blockchain)
    transaction(node_collection, blockchain, 0)
  end

  def transaction(node_collection, blockchain, i) when i < 99 do
    txn =
      create_txn(
        Enum.at(node_collection, i),
        Enum.at(node_collection, i + 1) |> getwallet_address,
        10
      )

    addTrans(node_collection, blockchain, txn)
    x = :ets.insert(:table78, {:length, 1})
    blockchain = :ets.lookup(:table78, :blockchain) |> Keyword.get(:blockchain)
    transaction(node_collection, blockchain, i + 1)

  end

  def transaction(node_collection, blockchain, i) when i == 99 do
  end

  def addTrans(node_collection, blockchain, txn) do
    blockchain = add_txn(blockchain, txn)
    x = :ets.insert(:table78, {:blockchain, blockchain})

    Enum.each(node_collection, fn k ->
      GenServer.cast(k, {:Add, node_collection})
    end)

    :timer.sleep(4000)
  end

  def handle_cast({:Add, node_collection}, state) do
    # IO.inspect(self())
    blockchain = :ets.lookup(:table78, :blockchain) |> Keyword.get(:blockchain)
    block = mining_pending_txns(blockchain, Map.get(state, "wallet_address"))

    length = :ets.lookup(:table78, :length) |> Keyword.get(:length)

    if length == 1 do
      x = :ets.insert(:table78, {:length, 2})

      IO.inspect(self())
      IO.puts("has mined the transaction")
      blockchain = %{blockchain | chain: blockchain.chain ++ [block]}
      blockchain = %{blockchain | pending_txns: []}
      x = :ets.insert(:table78, {:blockchain, blockchain})
    end

    {:noreply, state}
  end

  def new_node() do
    {:ok, pid} = GenServer.start_link(__MODULE__, [])
    GenServer.cast(pid, {:Create_Wallet})
    pid
  end

  def create_txn(pid, to_address, amount, fee \\ 0) do
    GenServer.call(pid, {:Create_Txn, [to_address, amount, fee]})
  end

  def getwallet_address(pid) do
    GenServer.call(pid, {:Get_Address})
  end

  def init(_args) do
    {:ok, %{}}
  end

  def handle_cast({:Create_Wallet}, _state) do
    {wallet_address, private_key} = :crypto.generate_key(:ecdh, :secp256k1)
    {:noreply, %{"wallet_address" => wallet_address, "private_key" => private_key}}
  end

  def handle_call({:Create_Txn, [to_address, amount, fee]}, _from, state) do
    txn = new_txn(Map.get(state, "wallet_address"), to_address, amount, fee)
    txn = sign(txn, Map.get(state, "wallet_address"), Map.get(state, "private_key"))
    {:reply, txn, state}
  end

  def handle_call({:Get_Address}, _from, state) do
    {:reply, Map.get(state, "wallet_address"), state}
  end
end
