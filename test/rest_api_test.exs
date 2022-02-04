defmodule RestApiTest do
  use ExUnit.Case
  doctest RestApi

  test "greets the world" do
    assert RestApi.hello() == :world
  end
end
