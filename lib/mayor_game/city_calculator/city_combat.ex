defmodule MayorGame.CityCombat do
  require Logger
  alias MayorGame.City
  alias MayorGame.City.{Town, OngoingAttacks, Buildable}
  alias MayorGame.{Repo}
  import Ecto.Query, warn: false

  def attack_city(%{} = attacked_city, attacking_town_id, amount) do
    attacking_town_struct = Repo.get!(Town, attacking_town_id)

    if amount < attacking_town_struct.missiles do
      # should do a reduce on amount here and attack shield bases first

      Enum.reduce(1..amount, attacked_city.shields, fn _amount, acc_shields ->
        if acc_shields > 0 do
          attack_shields(attacked_city, attacking_town_id, 1)
          acc_shields - 1
        else
          # reduce over buildings
          IO.inspect("reached buildings")

          building_to_attack =
            Enum.find(Buildable.buildables_attack_order(), fn building -> attacked_city[building] > 0 end)

          if !is_nil(building_to_attack), do: attack_building(attacked_city, attacking_town_id, building_to_attack)

          0
        end
      end)
    end
  end

  def attack_building(attacked_city, attacking_town_id, building_to_attack_atom) do
    # check if user is mayor here?

    attacking_town_struct = Repo.get!(Town, attacking_town_id)

    attacked_town_struct =
      if Map.has_key?(attacked_city, :__struct__), do: attacked_city, else: struct(City.Town, attacked_city)

    updated_attacked_logs = Map.update(attacked_city.logs_attacks, attacking_town_struct.title, 1, &(&1 + 1))

    attacked_town_changeset =
      attacked_town_struct
      |> City.Town.changeset(%{
        logs_attacks: updated_attacked_logs
      })

    # if attacked_city.shields <= 0 &&
    if attacking_town_struct.missiles > 0 &&
         attacking_town_struct.air_bases > 0 && attacked_town_struct[building_to_attack_atom] > 0 do
      attack =
        Town
        |> where(id: ^attacked_city.id)
        |> Repo.update_all(inc: [{building_to_attack_atom, -1}])

      case attack do
        {_x, nil} ->
          from(t in Town, where: [id: ^attacking_town_id])
          |> Repo.update_all(inc: [missiles: -1])

          attack_building =
            Ecto.Multi.new()
            |> Ecto.Multi.update(
              {:update_attacked_town, attacked_town_struct.id},
              attacked_town_changeset
            )
            |> Repo.transaction(timeout: 10_000)

          case attack_building do
            {:ok, _updated_details} ->
              IO.puts("attack success")

            {:error, err} ->
              Logger.error(inspect(err))
          end

        {:error, err} ->
          Logger.error(inspect(err))
      end
    end
  end

  @doc """
  takes attacked city struct, attacking_user_id, attack amount
  executes an attack on shields
  """
  def attack_shields(%{} = attacked_city, attacking_town_id, amount) do
    # see if I can figure out how to only get the missiles count here
    attacking_town_struct = Repo.get!(Town, attacking_town_id)

    shielded_town_struct =
      if Map.has_key?(attacked_city, :__struct__), do: attacked_city, else: struct(City.Town, attacked_city)

    attack_set =
      attacking_town_struct
      |> Town.changeset(%{missiles: amount})
      |> Ecto.Changeset.validate_number(:missiles,
        less_than: attacking_town_struct.missiles
      )

    attack_set =
      if attack_set.errors == [] do
        Map.put(attack_set, :changes, %{amount: amount})
      else
        Map.put(attack_set, :changes, %{amount: amount})
        |> Map.update!(:errors, fn current -> [amount: elem(hd(current), 1)] end)
        |> Map.put(:action, :insert)
      end

    # update cities

    if amount < attacking_town_struct.missiles && attacked_city.shields > 0 && attacking_town_struct.air_bases > 0 do
      amount = if amount > attacked_city.shields, do: attacked_city.shields, else: amount
      neg_amount = 0 - amount

      from(t in Town, where: [id: ^attacking_town_id])
      |> Repo.update_all(inc: [missiles: neg_amount])

      from(t in Town, where: [id: ^attacked_city.id])
      |> Repo.update_all(inc: [shields: neg_amount])

      # update logs
      updated_attacked_logs = Map.update(attacked_city.logs_attacks, attacking_town_struct.title, 1, &(&1 + amount))
      City.update_town(shielded_town_struct, %{logs_attacks: updated_attacked_logs})

      updated_city =
        attacked_city
        |> Map.update!(:shields, &(&1 - amount))
        |> Map.update!(:logs_attacks, fn current ->
          Map.update(current, attacking_town_struct.title, 1, &(&1 + amount))
        end)

      {:ok, updated_city, attack_set}
    else
      {:error, attacked_city, attack_set}
    end
  end

  @doc """
  Creates a new ongoing attack or increments the existing one between two cities
  Takes the attacked_town as a struct, and the id of the attacking town
  """
  def initiate_attack(%{} = attacked_town, attacking_town_id) do
    attacked_town_struct =
      struct(City.Town, attacked_town) |> Repo.preload([:attacks_sent, :attacks_recieved, :attacking, :attacked])

    attacking_town = Repo.get_by!(Town, id: attacking_town_id)

    if attacking_town.air_bases > 0 do
      existing_attack = Repo.get_by(OngoingAttacks, attacked_id: attacked_town.id, attacking_id: attacking_town_id)
      # ok this is nil if there's no existing attack
      # if there is, it returns the attack object

      # if no attack
      # return results
      if is_nil(existing_attack) do
        create_attack =
          Ecto.build_assoc(attacked_town_struct, :attacks_recieved, %{
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
