defmodule MayorGame.CityCombatTest do
  use MayorGame.DataCase
  import MayorGame.Fixtures
  alias MayorGame.CityCombat
  alias MayorGame.City.Town

  setup do
    attacker = town_fixture(%{air_bases: 1, missiles: 1_000})
    %{attacker: attacker}
  end

  test "missiles hit shields first, then buildings in attack order", %{attacker: attacker} do
    defender = town_fixture(%{shields: 2, defense_bases: 1, air_bases: 1})

    CityCombat.attack_city(defender, attacker.id, 3)

    defender = Repo.get!(Town, defender.id)
    assert defender.shields == 0
    assert defender.defense_bases == 0
    assert defender.air_bases == 1
  end

  test "an attack with more missiles than buildings stops at zero", %{attacker: attacker} do
    defender = town_fixture(%{shields: 0, defense_bases: 1, air_bases: 1, missile_defense_arrays: 0})

    CityCombat.attack_city(defender, attacker.id, 5)

    defender = Repo.get!(Town, defender.id)
    assert defender.defense_bases == 0
    assert defender.air_bases == 0
    assert Repo.get!(Town, attacker.id).missiles < 1_000
  end

  test "a building attack is logged once per hit", %{attacker: attacker} do
    defender = town_fixture(%{shields: 0, defense_bases: 2})

    CityCombat.attack_city(defender, attacker.id, 2)

    assert Repo.get!(Town, defender.id).logs_attacks == %{attacker.title => 2}
  end
end
