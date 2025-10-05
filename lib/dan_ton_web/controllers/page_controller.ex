defmodule DanTonWeb.PageController do
  use DanTonWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
