defmodule MayorGame.CityCombat do
  alias MayorGame.City.{Town, OngoingAttacks, Buildable}
  alias MayorGame.{Repo}
  import Ecto.Query, warn: false

  @doc """
  Fires `amount` missiles from the attacking town at the attacked town, one at a time:
  each hits a shield while the attacked town has any, then buildings in `Buildable.buildables_attack_order/0`.
  """
  def attack_city(%{} = attacked_city, attacking_town_id, amount) do
    if amount > 0 and amount < Repo.get!(Town, attacking_town_id).missiles do
      Enum.each(1..amount//1, fn _ ->
        # re-read the target every shot; the previous shot changed it
        attacked = Repo.get!(Town, attacked_city.id)

        if attacked.shields > 0 do
          attack_shields(attacked, attacking_town_id, 1)
        else
          building_to_attack = Enum.find(Buildable.buildables_attack_order(), &(attacked[&1] > 0))
          if building_to_attack, do: attack_building(attacked, attacking_town_id, building_to_attack)
        end
      end)
    end
  end

  @doc """
  Destroys one `building_to_attack_atom` in the attacked town, if the attacking town has an air base and enough
  missiles (the building's size). Returns true if the building was destroyed.
  """
  def attack_building(attacked_city, attacking_town_id, building_to_attack_atom) do
    attacking_town = Repo.get!(Town, attacking_town_id)
    building_cost = Buildable.buildables_flat()[building_to_attack_atom].size

    with true <- attacking_town.missiles >= building_cost && attacking_town.air_bases > 0,
         true <- hit(attacked_city.id, building_to_attack_atom, 1, attacking_town.title) do
      from(t in Town, where: [id: ^attacking_town_id]) |> Repo.update_all(inc: [missiles: -building_cost])
      true
    else
      _ -> false
    end
  end

  @doc """
  takes attacked city struct, attacking_town_id, attack amount
  executes an attack on shields

  returns {:ok | :error, attacked city with updated shields and logs, changeset for the attack form}
  """
  def attack_shields(%{} = attacked_city, attacking_town_id, amount) do
    attacking_town = Repo.get!(Town, attacking_town_id)

    attack_set =
      attacking_town
      |> Town.changeset(%{missiles: amount})
      |> Ecto.Changeset.validate_number(:missiles, less_than: attacking_town.missiles)

    attack_set =
      if attack_set.errors == [] do
        Map.put(attack_set, :changes, %{amount: amount})
      else
        Map.put(attack_set, :changes, %{amount: amount})
        |> Map.update!(:errors, fn current -> [amount: elem(hd(current), 1)] end)
        |> Map.put(:action, :insert)
      end

    # never fire more missiles than the target has shields
    amount = min(amount, Repo.get!(Town, attacked_city.id).shields)

    if amount > 0 && amount < attacking_town.missiles && attacking_town.air_bases > 0 &&
         hit(attacked_city.id, :shields, amount, attacking_town.title) do
      from(t in Town, where: [id: ^attacking_town_id]) |> Repo.update_all(inc: [missiles: -amount])

      updated_city =
        attacked_city
        |> Map.update!(:shields, &(&1 - amount))
        |> Map.update!(:logs_attacks, &Map.update(&1, attacking_town.title, amount, fn hits -> hits + amount end))

      {:ok, updated_city, attack_set}
    else
      {:error, attacked_city, attack_set}
    end
  end

  # Removes `amount` of `field` (shields or a building) from the attacked town and adds `amount` to its
  # logs_attacks for the attacker, in one atomic update. Does nothing if the town has less than `amount`.
  defp hit(attacked_id, field, amount, attacker_title) do
    {count, _} =
      from(t in Town,
        where: t.id == ^attacked_id and field(t, ^field) >= ^amount,
        update: [
          inc: ^[{field, -amount}],
          set: [
            logs_attacks:
              fragment(
                "jsonb_set(coalesce(?, '{}'::jsonb), ARRAY[?::text], to_jsonb(coalesce((?->>?::text)::bigint, 0) + ?))",
                t.logs_attacks,
                ^attacker_title,
                t.logs_attacks,
                ^attacker_title,
                ^amount
              )
          ]
        ]
      )
      |> Repo.update_all([])

    count == 1
  end

  @doc """
  Creates a new ongoing attack or increments the existing one between two cities
  Takes the attacked_town as a struct, and the id of the attacking town
  """
  def initiate_attack(%{} = attacked_town, attacking_town_id) do
    # attacked_town_struct = attacked_town |> Repo.preload([:attacks_sent, :attacks_recieved, :attacking, :attacked])

    attacking_town = Repo.get_by!(Town, id: attacking_town_id)

    if attacking_town.air_bases > 0 do
      existing_attack = Repo.get_by(OngoingAttacks, attacked_id: attacked_town.id, attacking_id: attacking_town_id)
      # ok this is nil if there's no existing attack
      # if there is, it returns the attack object

      # if no attack
      # return results
      if is_nil(existing_attack) do
        create_attack =
          Ecto.build_assoc(attacked_town, :attacks_recieved, %{
            attack_count: 1,
            attacking_id: attacking_town_id
          })

        Repo.insert!(create_attack)
      else
        updated_attack = existing_attack |> OngoingAttacks.changeset(%{attack_count: existing_attack.attack_count + 1})

        Repo.update!(updated_attack)
      end
    else
      {:error, "no airbases"}
    end
  end

  @doc """
  Reduces intensity of an attack
  Takes the attacked_town as a struct, and the id of the attacking town
  """
  def reduce_attack(%{} = attacked_town, attacking_town_id) do
    # attacked_town_struct =
    #   struct(City.Town, attacked_town) |> Repo.preload([:attacks_sent, :attacks_recieved, :attacking, :attacked])

    existing_attack = Repo.get_by(OngoingAttacks, attacked_id: attacked_town.id, attacking_id: attacking_town_id)
    # ok this is nil if there's no existing attack
    # if there is, it returns the attack object

    # if no attack
    # return results
    if !is_nil(existing_attack) do
      if existing_attack.attack_count > 1 do
        updated_attack = existing_attack |> OngoingAttacks.changeset(%{attack_count: existing_attack.attack_count - 1})

        Repo.update!(updated_attack)
      else
        Repo.delete!(existing_attack)
      end
    end
  end
end
