defmodule Horus.Repo do
  use Ecto.Repo,
    otp_app: :horus,
    adapter: Ecto.Adapters.Postgres
end
