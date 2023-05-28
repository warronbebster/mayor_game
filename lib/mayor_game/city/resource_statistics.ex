defmodule MayorGame.City.ResourceStatistics do
  alias __MODULE__
  use Accessible
  alias MayorGame.City.{TownStatistics}
  # education, unlike all other resources, uses a map
  # this can complicate things quite a bit. We can make this struct work with maps but it may occur expensive checks for all resources, for the benefit of one resource
  # for now, we split it to education_lvl_1, education_lvl_2 etc. And reserve a special education resource for libraries for random drop across all levels

  defstruct [
    :title,
    stock: 0,
    storage: nil,
    production: 0,
    consumption: 0,
    droplist: []
  ]

  # fn _rng, _number_of_instances -> drop_amount
  # fn _rng, _number_of_instances, _city -> drop_amount
  @type dropfunction ::
          (number, integer -> integer) | (number, integer, TownStatistics.t() -> integer) | nil

  @type t :: %ResourceStatistics{
          title: String.t(),
          stock: integer,
          storage: integer | nil,
          production: integer,
          consumption: integer,
          droplist: list({integer, dropfunction})
        }

  @spec merge(ResourceStatistics.t(), ResourceStatistics.t(), integer) :: ResourceStatistics.t()
  def merge(source, child, quantity \\ 1) do
    %ResourceStatistics{
      title: source.title,
      stock: source.stock + child.stock * quantity,
      storage:
        if is_nil(source.storage) do
          if is_nil(child.storage) do
            nil
          else
            child.storage * quantity
          end
        else
          if is_nil(child.storage) do
            source.storage
          else
            source.storage + child.storage * quantity
          end
        end,
      production: source.production + child.production * quantity,
      consumption: source.consumption + child.consumption * quantity,
      droplist:
        if is_nil(source.droplist) do
          []
        else
          source.droplist
        end ++
          if is_nil(child.droplist) do
            []
          else
            List.flatten(List.duplicate(child.droplist, quantity))
          end
    }
  end

  @spec multiply(ResourceStatistics.t(), integer) :: ResourceStatistics.t()
  def multiply(source, quantity \\ 1) do
    %ResourceStatistics{
      title: source.title,
      stock: source.stock * quantity,
      storage:
        if is_nil(source.storage) do
          nil
        else
          source.storage * quantity
        end,
      production: source.production * quantity,
      consumption: source.consumption * quantity,
      droplist: List.flatten(List.duplicate(source.droplist, quantity))
    }
  end

  @spec fromProduces(String.t(), integer, integer | nil, list({integer, dropfunction})) ::
          ResourceStatistics.t()
  def fromProduces(title, value, storage \\ nil, droplist \\ []) do
    %ResourceStatistics{
      title: title,
      stock: 0,
      storage: storage,
      production:
        if value > 0 do
          value
        else
          0
        end,
      consumption:
        if value > 0 do
          0
        else
          -value
        end,
      droplist:
        if is_nil(droplist) do
          []
        else
          droplist
        end
    }
  end

  @doc """
   I think this creates a new statistic from what's required, which then you can merge with the existing resource statistic
  """
  @spec fromRequires(String.t(), integer, integer | nil) :: ResourceStatistics.t()
  def fromRequires(title, value, storage \\ nil) do
    %ResourceStatistics{
      title: title,
      stock: 0,
      storage:
        if is_nil(storage) do
          nil
        else
          -storage
        end,
      production:
        if value > 0 do
          0
        else
          -value
        end,
      consumption:
        if value > 0 do
          value
        else
          0
        end,
      droplist: []
    }
  end

  @spec getStock(ResourceStatistics.t(), integer) :: integer
  def getStock(stat, additive \\ 0) do
    stat.stock + additive
  end

  @spec getStorage(ResourceStatistics.t()) :: integer | nil
  def getStorage(stat) do
    stat.storage
  end

  @spec getProduction(ResourceStatistics.t()) :: integer
  def getProduction(stat) do
    stat.production
  end

  @spec getConsumption(ResourceStatistics.t()) :: integer
  def getConsumption(stat) do
    stat.consumption
  end

  @spec getNextStock(ResourceStatistics.t()) :: integer
  def getNextStock(stat) do
    getStock(stat) + getNetProduction(stat)
  end

  @spec getNetProduction(ResourceStatistics.t()) :: integer
  def getNetProduction(stat) do
    stat.production - stat.consumption
  end

  @spec expressStock_SI(ResourceStatistics.t(), integer) :: String.t()
  def expressStock_SI(stat, additive \\ 0) do
    Number.SI.number_to_si(stat.stock + additive, precision: 3, trim: true)
  end

  @spec expressStockOverStorage_SI(ResourceStatistics.t(), integer) :: String.t()
  def expressStockOverStorage_SI(stat, additive \\ 0) do
    if is_nil(stat.storage) do
      Number.SI.number_to_si(stat.stock + additive, precision: 3, trim: true)
    else
      Number.SI.number_to_si(stat.stock + additive, precision: 2, trim: true) <>
        "/" <>
        Number.SI.number_to_si(stat.storage, precision: 2, trim: true)
    end
  end

  @spec expressProduction_SI(ResourceStatistics.t()) :: String.t()
  def expressProduction_SI(stat) do
    Number.SI.number_to_si(stat.production, precision: 3, trim: true)
  end

  @spec expressConsumption_SI(ResourceStatistics.t()) :: String.t()
  def expressConsumption_SI(stat) do
    Number.SI.number_to_si(stat.consumption, precision: 3, trim: true)
  end

  @spec expressNetProduction_SI(ResourceStatistics.t()) :: String.t()
  def expressNetProduction_SI(stat) do
    Number.SI.number_to_si(getNetProduction(stat), precision: 3, trim: true)
  end

  @spec expressAvailableOverSupply_SI(ResourceStatistics.t()) :: String.t()
  def expressAvailableOverSupply_SI(stat) do
    Number.SI.number_to_si(getNetProduction(stat), precision: 3, trim: true) <>
      "/" <>
      Number.SI.number_to_si(stat.production, precision: 3, trim: true)
  end

  @spec expressStock_delimited(ResourceStatistics.t(), integer) :: String.t()
  def expressStock_delimited(stat, additive \\ 0) do
    Number.Delimit.number_to_delimited(stat.stock + additive)
  end

  @spec expressStockOverStorage_delimited(ResourceStatistics.t(), integer) :: String.t()
  def expressStockOverStorage_delimited(stat, additive \\ 0) do
    if is_nil(stat.storage) do
      Number.Delimit.number_to_delimited(stat.stock + additive)
    else
      Number.Delimit.number_to_delimited(stat.stock + additive) <>
        "/" <>
        Number.Delimit.number_to_delimited(stat.storage)
    end
  end

  @spec expressNetProduction_delimited(ResourceStatistics.t()) :: String.t()
  def expressNetProduction_delimited(stat) do
    Number.Delimit.number_to_delimited(getNetProduction(stat))
  end

  @spec expressAvailableOverSupply_delimited(ResourceStatistics.t()) :: String.t()
  def expressAvailableOverSupply_delimited(stat) do
    Number.Delimit.number_to_delimited(getNetProduction(stat)) <>
      "/" <> Number.Delimit.number_to_delimited(stat.production)
  end

  def resource_kw_list() do
    [
      {:sulfur, "orange-700"},
      {:uranium, "violet-700"},
      {:steel, "slate-700"},
      {:fish, "cyan-700"},
      {:oil, "stone-700"},
      {:gas, "orange-700"},
      {:gold, "amber-500"},
      {:coal, "stone-700"},
      {:stone, "slate-700"},
      {:bread, "amber-800"},
      {:wheat, "amber-600"},
      {:grapes, "indigo-700"},
      {:wood, "amber-700"},
      {:beer, "amber-700"},
      {:wine, "rose-700"},
      {:food, "yellow-700"},
      {:produce, "green-700"},
      {:meat, "red-700"},
      {:rice, "yellow-700"},
      {:cows, "stone-700"},
      {:lithium, "lime-700"},
      {:sand, "yellow-700"},
      {:glass, "sky-600"},
      {:water, "sky-700"},
      {:salt, "zinc-700"},
      {:missiles, "red-700"},
      {:shields, "blue-700"}
    ]
  end

  def resource_list() do
    Keyword.keys(resource_kw_list())
  end
end
