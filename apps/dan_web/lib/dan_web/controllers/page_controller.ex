defmodule DanWeb.PageController do
  use DanWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
