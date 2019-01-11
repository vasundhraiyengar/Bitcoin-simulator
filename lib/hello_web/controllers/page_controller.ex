defmodule HelloWeb.PageController do
  use HelloWeb, :controller

  def index(conn, _params) do

    {pending_txns, completed_txns}=Project4.getdata()
    tdata=Project4.test()
    total_coins=Project4.total_miningrewards()
    block_list=Project4.no_of_blocks()
    t=Project4.total_amount_transacted()
    tm=Project4.tm()
    render(conn, "index.html", pending_txns: pending_txns, completed_txns: completed_txns, tdata: tdata, total_coins: total_coins, block_list: block_list, t: t, tm: tm)
  end
end
