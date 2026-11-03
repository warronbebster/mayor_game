defmodule MayorGame.CitizensTest do
  use ExUnit.Case, async: true
  alias MayorGame.City.Citizens

  test "compressing and unfolding citizens keeps them, with ages rounded to 100 days" do
    day = 5_000

    citizens = [
      %{"age" => 120, "education" => 0, "preferences" => 3},
      %{"age" => 120, "education" => 0, "preferences" => 3},
      %{"age" => 2_000, "education" => 4, "preferences" => 11}
    ]

    unfolded = citizens |> Citizens.compress_citizen_blob(day) |> Citizens.unfold_citizen_blob(day, 7)

    assert length(unfolded) == 3
    assert Enum.all?(unfolded, &(&1["town_id"] == 7))

    assert unfolded |> Enum.map(&{&1["education"], &1["preferences"], &1["age"]}) |> Enum.sort() == [
             {0, 3, 100},
             {0, 3, 100},
             {4, 11, 2_000}
           ]
  end

  test "no citizens" do
    assert Citizens.compress_citizen_blob([], 10) == %{}
    assert Citizens.unfold_citizen_blob(%{}, 10, 1) == []
  end
end
