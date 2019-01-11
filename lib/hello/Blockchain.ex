defmodule Blockchain do
  import Transaction

  defstruct [
    :index,
    :previous_hash,
    :timestamp,
    :transactions,
    :nonce,
    :hash,
    :merkle_tree_root
  ]

  def create_new_block(index, transactions, pre_hash) do
    b = %Blockchain{
      index: index + 1,
      previous_hash: pre_hash,
      timestamp: System.system_time(:second),
      transactions: transactions,
      merkle_tree_root: nil
    }

    b = %{b | nonce: proof_of_work(b)}
    hash = compute_hash(b)
    %{b | hash: hash}
  end

  def genesis_block do
    b = %Blockchain{
      index: 0,
      previous_hash: "0",
      timestamp: System.system_time(:second),
      transactions: [],
      nonce: 0,
      hash: ""
    }

    b = %{b | nonce: proof_of_work(b)}
    hash = compute_hash(b)
    b2 = %{b | hash: hash}
    chain = [b2]
    blockchain = %{chain: chain, pending_txns: '', difficulty: 2, mining_reward: 100}
    blockchain
  end

  def compute_hash(%Blockchain{
        index: i,
        previous_hash: h,
        timestamp: timestamp,
        transactions: transactions,
        nonce: nonce
      }) do
    hash = Enum.join([i, h, timestamp, Kernel.inspect(transactions), nonce])
    :crypto.hash(:sha256, hash) |> Base.encode16()
  end

  def proof_of_work(%Blockchain{} = block, nonce \\ 0) do
    b = %{block | nonce: nonce}
    hash = compute_hash(b)

    case verify_proof_of_work(hash) do
      true -> nonce
      _ -> proof_of_work(block, nonce + 1)
    end
  end

  def verify_proof_of_work(hash) do
    difficulty = 2
    prefix = Enum.reduce(1..difficulty, "", fn _, acc -> "0#{acc}" end)
    String.starts_with?(hash, prefix)
  end

  def add_txn(chain, transaction) do
    if transaction.from_address == "" or transaction.to_address == "" do
      throw("Transaction should include to and from address")
    end

    if !is_valid(transaction) do
      throw("Invalid transaction cannot be added")
    end

    if transaction.from_address != nil do
      if(get_balance(chain, transaction.from_address) < transaction.amount + transaction.fee) do
        throw("Insufficient Funds")
      else
        total =
          get_balance(chain, transaction.from_address) -
            Enum.reduce(chain.pending_txns, 0, fn x, acc -> acc + x.amount + x.fee end) -
            transaction.amount - transaction.fee

        if total < 0 do
          throw("Balance already utilized")
        end
      end
    end

    %{chain | pending_txns: chain.pending_txns ++ [transaction]}
  end

  def mining_pending_txns(blockchain, reward_address) do
    mining_fee = Enum.reduce(blockchain.pending_txns, 0, fn x, acc -> acc + x.fee end)

    blockchain =
      add_txn(blockchain, new_txn(nil, reward_address, blockchain.mining_reward + mining_fee))

    b =
      create_new_block(
        List.last(blockchain.chain).index,
        blockchain.pending_txns,
        List.last(blockchain.chain).hash
      )

    b = mining_block(b, blockchain.difficulty)
    b
  end

  def get_balance(blockchain, address) do
    blocks = blockchain.chain

    Enum.reduce(blocks, 0, fn x, acc ->
      transactions = x.transactions

      acc +
        Enum.reduce(transactions, 0, fn y, minacc ->
          cond do
            y.from_address == address -> minacc - y.amount - y.fee
            y.to_address == address -> minacc + y.amount
            true -> minacc
          end
        end)
    end)
  end

  def merkle_tree(block, transactions) do
    if length(transactions) == 1 do
      %{block | merkle_tree_root: List.last(transactions)}
    else
      transactions =
        if rem(length(transactions), 2) == 1 do
          transactions ++ [List.last(transactions)]
        else
          transactions
        end

      transactions =
        Enum.reduce(Enum.take_every(1..length(transactions), 2), [], fn x, acc ->
          acc ++
            [
              :crypto.hash(
                :sha256,
                Enum.join([Enum.at(transactions, x), Enum.at(transactions, x + 1)])
              )
              |> Base.encode16()
            ]
        end)

      merkle_tree(block, transactions)
    end
  end

  def mining_block(block, difficulty) do
    if String.slice(block.hash, 0..(difficulty - 1)) != String.duplicate("0", difficulty) do
      block = %{block | nonce: block.nonce + 1}
      block = compute_hash(block)
      mining_block(block, difficulty)
    else
      block =
        merkle_tree(
          block,
          Enum.map(block.transactions, fn x ->
            :crypto.hash(
              :sha256,
              Enum.join([x.from_address, x.to_address, x.amount, x.signature])
            )
            |> Base.encode16()
          end)
        )

      block
    end
  end

  def validate_chain(blockchain) do
    blocks = blockchain.chain

    Enum.reduce(Enum.slice(blocks, 1, length(blocks)), true, fn x, acc ->
      previous = Enum.at(blocks, Enum.find_index(blocks, fn k -> x == k end) - 1)

      cond do
        !check_valid_txns(x) -> acc and false
        compute_hash(x) != x.hash -> acc and false
        x.previous_hash != previous.hash -> acc and false
        true -> acc and true
      end
    end)
  end

  def check_valid_txns(block) do
    transactions = block.transactions

    Enum.reduce(transactions, true, fn x, acc ->
      acc and is_valid(x)
    end)
  end
end
