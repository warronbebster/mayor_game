defmodule MayorGame.Rules do
  alias MayorGame.City.{World}

  @spec building_price(integer, integer) :: integer
  def building_price(initial_price, buildable_count) do
    initial_price * round(:math.pow(buildable_count, 2) + 1)
  end

  @spec calculate_earnings(integer, integer, number) :: integer
  def calculate_earnings(worker_count, level, tax_rate) do
    round(worker_count * :math.pow(2, level) * 100 * (tax_rate / 10))
  end

  @spec is_citizen_reproductive(map) :: boolean
  def is_citizen_reproductive(citizen) do
    citizen["age"] > 15 && citizen["age"] < 4000 && :rand.uniform() > 0.99
  end

  @spec is_citizen_within_lifespan(map) :: boolean
  def is_citizen_within_lifespan(citizen) do
    citizen["age"] < 3000 * (citizen["education"] + 1)
  end

  @spec is_citizen_restless(map, %World{}) :: boolean
  def is_citizen_restless(citizen, world) do
    citizen["last_moved"] < world.day - 10 * citizen["education"]
  end

  @spec excessive_tax_chance(integer, number) :: number
  def excessive_tax_chance(level, tax_rate) do
    :math.pow(tax_rate, 7 - level)
  end

  @spec season_from_day(integer) :: atom
  def season_from_day(day) do
    cond do
      rem(day, 365) < 91 -> :winter
      rem(day, 365) < 182 -> :spring
      rem(day, 365) < 273 -> :summer
      true -> :fall
    end
  end
end
