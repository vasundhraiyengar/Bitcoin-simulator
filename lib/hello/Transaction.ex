defmodule Transaction do
  defstruct [
    :from_address,
    :to_address,
    :amount,
    :signature,
    :fee
  ]

  def new_txn(from_address, to_address, amount, fee \\ 0) do
    %Transaction{from_address: from_address, to_address: to_address, amount: amount, fee: fee}
  end

  def compute_txn_hash(transaction) do
    hash =
      Enum.join([
        transaction.from_address,
        transaction.to_address,
        transaction.amount
      ])

    :crypto.hash(:sha256, hash) |> Base.encode16()
  end

  def sign(transaction, public_key, private_key) do
    if transaction.from_address != public_key do
      {:error, "Invalid signature. You can only sign your transactions."}
    else
      hash = compute_txn_hash(transaction)
      %{transaction | signature: :crypto.sign(:ecdsa, :sha256, hash, [private_key, :secp256k1])}
    end
  end

  def is_valid(transaction) do
    if transaction.from_address == nil do
      true
    else
      if transaction.signature == nil do
        throw("Signature missing")
      end

      :crypto.verify(:ecdsa, :sha256, compute_txn_hash(transaction), transaction.signature, [
        transaction.from_address,
        :secp256k1
      ])
    end
  end
end
