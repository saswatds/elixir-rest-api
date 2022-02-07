defmodule RestApi.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {
        Plug.Cowboy,
        scheme: :http,
        plug: RestApi.Router,
        options: [port: Application.get_env(:rest_api, :port)]
      },
      {
        Mongo,
        [
          name: :mongo,
          database: Application.get_env(:rest_api, :database),
          pool_size: Application.get_env(:rest_api, :pool_size)
        ]
      }
    ]

    opts = [strategy: :one_for_one, name: RestApi.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
