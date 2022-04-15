defmodule RestApi.Router do
  alias RestApi.JSONUtils, as: JSON

  use Plug.Router

  plug(Plug.Logger)
  plug(:match)

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason
  )

  plug(:dispatch)

  get "/" do
    send_resp(conn, 200, "OK")
  end

  get "/knockknock" do
    case Mongo.command(:mongo, ping: 1) do
      {:ok, _res} -> send_resp(conn, 200, "Who's there?")
      {:error, _err} -> send_resp(conn, 500, "Something went wrong")
    end
  end

  get "/posts" do
    posts =
      Mongo.find(:mongo, "Posts", %{})
      |> Enum.map(&JSON.normaliseMongoId/1)
      |> Enum.to_list()
      |> Jason.encode!()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, posts)
  end

  post "/post" do
    case conn.body_params do
      %{"name" => name, "content" => content} ->
        case Mongo.insert_one(:mongo, "Posts", %{"name" => name, "content" => content}) do
          {:ok, user} ->
            doc = Mongo.find_one(:mongo, "Posts", %{_id: user.inserted_id})

            post =
              JSON.normaliseMongoId(doc)
              |> Jason.encode!()

            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, post)

          {:error, _} ->
            send_resp(conn, 500, "Something went wrong")
        end

      _ ->
        send_resp(conn, 400, '')
    end
  end

  get "/post/:id" do
    doc = Mongo.find_one(:mongo, "Posts", %{_id: BSON.ObjectId.decode!(id)})

    case doc do
      nil ->
        send_resp(conn, 404, "Not Found")

      %{} ->
        post =
          JSON.normaliseMongoId(doc)
          |> Jason.encode!()

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, post)

      {:error, _} ->
        send_resp(conn, 500, "Something went wrong")
    end
  end

  put "post/:id" do
    case Mongo.find_one_and_update(
           :mongo,
           "Posts",
           %{_id: BSON.ObjectId.decode!(id)},
           %{
             "$set":
               conn.body_params
               |> Map.take(["name", "content"])
               |> Enum.into(%{}, fn {key, value} -> {"#{key}", value} end)
           },
           return_document: :after
         ) do
      {:ok, doc} ->
        case doc do
          nil ->
            send_resp(conn, 404, "Not Found")

          _ ->
            post =
              JSON.normaliseMongoId(doc)
              |> Jason.encode!()

            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, post)
        end

      {:error, _} ->
        send_resp(conn, 500, "Something went wrong")
    end
  end

  delete "post/:id" do
    Mongo.delete_one!(:mongo, "Posts", %{_id: BSON.ObjectId.decode!(id)})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{id: id}))
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
