defmodule BitcoinTest do
  use ExUnit.Case
  import Transaction
  import Blockchain
  import Project4

  test "Check block creation" do
    t = System.system_time(:second)
    block = create_new_block(1, [], "")
    assert block.index == 2
    assert block.timestamp == t
    assert block.transactions == []
    assert block.nonce == proof_of_work(block)
  end

  test "Check blockchain creation" do
    t = System.system_time(:second)
    blockchain = genesis_block()
    assert Enum.at(blockchain.chain, 0).timestamp == t
    assert Enum.at(blockchain.chain, 0).transactions == []
    assert blockchain.difficulty == 2
    assert blockchain.mining_reward == 100
  end

  test "Check transaction creation" do
    txn = new_txn("from_address", "to_address", 100)
    assert txn.from_address == "from_address"
    assert txn.to_address == "to_address"
    assert txn.amount == 100
  end

  test "Check valid transaction added to pending transactions" do
    blockchain = genesis_block()
    {sender_address, private_key} = :crypto.generate_key(:ecdh, :secp256k1)
    txn = new_txn(sender_address, "receiver_address", 10)
    txn = sign(txn, sender_address, private_key)
    blockchain = mining_pending_txns(blockchain, sender_address)
    txn = sign(txn, sender_address, private_key)
    blockchain = add_txn(blockchain, txn)
    assert List.last(blockchain.pending_txns) == txn
  end

  test "Check invalid transaction- incorrect signature" do
    blockchain = genesis_block()
    txn = new_txn("sender_address", "receiver_address", 10)
    txn = %{txn | signature: "Random other signature"}
    block = catch_throw(add_txn(blockchain, txn))
    assert block == "Invalid transaction cannot be added"
  end

  test "Check invalid transaction- no to address" do
    blockchain = genesis_block()
    txn = new_txn("sender_public_key", "", 10)
    block = catch_throw(add_txn(blockchain, txn))
    assert block == "Transaction should include to and from address"
  end

  test "Check invalid transaction- unsigned" do
    blockchain = genesis_block()
    {sender_address, _} = :crypto.generate_key(:ecdh, :secp256k1)
    txn = new_txn(sender_address, "receiver_public_key", 10)
    block = catch_throw(add_txn(blockchain, txn))
    assert block == "Signature missing"
  end

  test "Check invalid transaction- no from address" do
    blockchain = genesis_block()
    txn = new_txn("", "receiver_public_key", 10)
    block = catch_throw(add_txn(blockchain, txn))
    assert block == "Transaction should include to and from address"
  end

  test "Check block change in hash" do
    block = create_new_block(1, [], "")
    # Change the block and check change in hash
    block = %{block | timestamp: 123}
    assert block.hash != compute_hash(block)
  end

  test "Check validity of block on modification" do
    blockchain = genesis_block()
    {my_address, private_key} = :crypto.generate_key(:ecdh, :secp256k1)
    txn = new_txn(my_address, "public_key", 20)
    txn = sign(txn, my_address, private_key)
    blockchain = mining_pending_txns(blockchain, my_address)
    blockchain = add_txn(blockchain, txn)
    blockchain = mining_pending_txns(blockchain, my_address)
    assert validate_chain(blockchain) == true
    # Modifying a completed transaction
    txn = %{txn | amount: 500}
    block = Enum.at(blockchain.chain, 1)
    block = %{block | transactions: List.replace_at(block.transactions, 0, txn)}
    blockchain = %{blockchain | chain: List.replace_at(blockchain.chain, 1, block)}
    assert validate_chain(blockchain) == false
  end

  test "Check if there's enough balance for transaction" do
    blockchain = genesis_block()
    {my_address, private_key} = :crypto.generate_key(:ecdh, :secp256k1)
    txn = new_txn(my_address, "public_key", 10)
    txn = sign(txn, my_address, private_key)
    block = catch_throw(add_txn(blockchain, txn))
    assert block == "Insufficient Funds"
  end

  test "Check hashing for block hash" do
    blockchain = genesis_block()
    pre_hash = Enum.at(blockchain.chain, 0).hash
    block = create_new_block(1, [], pre_hash)

    hash =
      Enum.join([
        block.index,
        block.previous_hash,
        block.timestamp,
        Kernel.inspect(block.transactions),
        block.nonce
      ])

    assert :crypto.hash(:sha256, hash) |> Base.encode16() == block.hash
  end

  test "Check hashing for transaction hash" do
    txn = new_txn("from_address", "to_address", 10)
    hash = compute_txn_hash(txn)

    assert hash ==
             :crypto.hash(:sha256, Enum.join([txn.from_address, txn.to_address, txn.amount]))
             |> Base.encode16()
  end

  test "Check balances after transaction" do
    blockchain = genesis_block()
    node1 = new_node()
    node2 = new_node()
    blockchain = mining_pending_txns(blockchain, getwallet_address(node1))
    # Node 1 sending 10 to Node 2 without fee
    txn = create_txn(node1, getwallet_address(node2), 10, 0)
    blockchain = add_txn(blockchain, txn)
    blockchain = mining_pending_txns(blockchain, getwallet_address(node1))
    assert get_balance(blockchain, getwallet_address(node1)) == 190
    assert get_balance(blockchain, getwallet_address(node2)) == 10
  end

  test "Check balance after transaction with fee" do
    blockchain = genesis_block()
    node1 = new_node()
    node2 = new_node()
    blockchain = mining_pending_txns(blockchain, getwallet_address(node1))
    # Node 1 sending 10 to Node 2 fee 10
    txn = create_txn(node1, getwallet_address(node2), 10, 10)
    blockchain = add_txn(blockchain, txn)
    # 100-10-10
    blockchain = mining_pending_txns(blockchain, getwallet_address(node2))
    assert get_balance(blockchain, getwallet_address(node1)) == 80
  end

  test "Check mining reward balance" do
    blockchain = genesis_block()
    node1 = new_node()
    node2 = new_node()
    node3 = new_node()
    blockchain = mining_pending_txns(blockchain, getwallet_address(node1))
    # Node 1 sending 10 to Node 2 without fee
    txn = create_txn(node1, getwallet_address(node2), 10, 0)
    blockchain = add_txn(blockchain, txn)
    # Mine and send reward to Node 3
    blockchain = mining_pending_txns(blockchain, getwallet_address(node3))
    assert get_balance(blockchain, getwallet_address(node3)) == 100
  end

  test "Checking enough balance for transaction" do
    blockchain = genesis_block()
    node1 = new_node()
    node2 = new_node()
    blockchain = mining_pending_txns(blockchain, getwallet_address(node1))
    # Node 1 sending 100 to node 2
    txn = create_txn(node1, getwallet_address(node2), 200)
    block = catch_throw(add_txn(blockchain, txn))
    assert block == "Insufficient Funds"
  end

  test "Check if all balance utilized" do
    blockchain = genesis_block()
    node1 = new_node()
    node2 = new_node()
    blockchain = mining_pending_txns(blockchain, getwallet_address(node1))
    txn = create_txn(node1, getwallet_address(node2), 10, 10)
    blockchain = add_txn(blockchain, txn)
    # Node 1 sending 100 to node 2
    txn = create_txn(node1, getwallet_address(node2), 100)
    block = catch_throw(add_txn(blockchain, txn))
    assert block == "Balance already utilized"
  end
end
