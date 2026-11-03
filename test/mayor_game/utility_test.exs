defmodule MayorGame.UtilityTest do
  use ExUnit.Case, async: true
  alias MayorGame.Utility

  test "dice_roll/2 counts successes, including for a single building" do
    assert Utility.dice_roll(0, 0.5) == 0
    assert Utility.dice_roll(1, 1.0) == 1
    assert Utility.dice_roll(1, 0.0) == 0
    # (the statistics library hangs on exactly 0 or 1 for more than one trial; the game uses 0.05 and 0.001)
    rolls = for _ <- 1..200, do: Utility.dice_roll(10, 0.05)
    assert Enum.all?(rolls, &(is_integer(&1) and &1 in 0..10))
    assert Enum.sum(rolls) > 0
  end
end
