defmodule MayorGame.City.Resource do
  alias MayorGame.City.{ResourceMetadata}
  use Accessible

  def resource_category_descriptions do
    %{
      basic:
        "Resources that are tied to the core mechanics of the game.",
      sustenance:
        "These resources keep citizens alive.",
      materials:
        "These resources are typically accumulated by the city. Some of these resources may be associated with a storage maximum",
      combat:
        "These resources are used in combat",
      utilities:
        "These resources are typically utilities and consumed in the city. Generally, consumption will not excced supply",
      quality_of_life:
        "These resources represent a city's attribute. These metrics may be used by citizens to determine their preferred cities",
    }
  end

  def resources_city_display_rows do
    [
      [
        pollution: resources_flat().pollution,
        housing: resources_flat().housing,
        workers: resources_flat().workers,
        income: resources_flat().income,
        maintenance: resources_flat().maintenance,
        money: resources_flat().money,
      ],
      [
        area: resources_flat().area,
        energy: resources_flat().energy,
        health: resources_flat().health,
        fun: resources_flat().fun,
        sprawl: resources_flat().sprawl,
        steel: resources_flat().steel,
        sulfur: resources_flat().sulfur,
        uranium: resources_flat().uranium,
        missiles: resources_flat().missiles,
        shields: resources_flat().shields,
      ],
    ]
  end

  def resources do
    resources_kw_list() |> Enum.into(%{})
  end

  def resources_kw_list do
    [
      basic: [
        pollution: resources_flat().pollution,
        money: resources_flat().money,
        income: resources_flat().income,
        maintenance: resources_flat().maintenance,
        education: resources_flat().education,
        workers: resources_flat().workers,
      ],
      sustenance: [
        water: resources_flat().water,
        fish: resources_flat().fish,
      ],
      materials: [
        wood: resources_flat().wood,
        stone: resources_flat().stone,
        steel: resources_flat().steel,
        sulfur: resources_flat().sulfur,
        oil: resources_flat().oil,
        salt: resources_flat().salt,
        lithium: resources_flat().lithium,
        uranium: resources_flat().uranium,
      ],
      combat: [
        missiles: resources_flat().missiles,
        shields: resources_flat().shields,
      ],
      utilities: [
        area: resources_flat().area,
        housing: resources_flat().housing,
        energy: resources_flat().energy,
      ],
      quality_of_life: [
        health: resources_flat().health,
        fun: resources_flat().fun,
        sprawl: resources_flat().sprawl,
      ],
    ]
  end

  def resources_flat do
    %{
      # MATERIAL RESOURCES ——————————————————————————————————
      ### A materials resource is usually represented as 'amount', or if limited storage is implemented, 'amount / storage'. Generally, resources in excess of storage are wasted and removed
      # pollution ————————————————————————————————————
      pollution: %ResourceMetadata{
        title: :pollution,
        description: "The elephant in the room. The world can only take so much pollution before its ability to sustain life is affected.",
        image_sources: ["/images/pollution.svg"],
        text_color_class: "text-purple-800",
        city_stock_display: nil
      },
      # money ————————————————————————————————————
      money: %ResourceMetadata{
        title: :money,
        description: "Money makes the world go round~",
        image_sources: ["/images/money-fulfilled.svg"],
        text_color_class: "text-green-700",
        city_stock_display: nil
      },
      # wood ————————————————————————————————————
      wood: %ResourceMetadata{
        title: :wood,
        description: "Wood is not in use by the game yet",
        image_sources: ["/images/wood.svg"],
        text_color_class: "text-amber-700",
        city_stock_display: nil
      },
      # stone ————————————————————————————————————
      stone: %ResourceMetadata{
        title: :stone,
        description: "Stone is not in use by the game yet",
        image_sources: ["/images/stone.svg"],
        text_color_class: "text-slate-700",
        city_stock_display: nil
      },
      # steel ————————————————————————————————————
      steel: %ResourceMetadata{
        title: :steel,
        description: "Steel is an essential building component of other resources",
        image_sources: ["/images/steel.svg"],
        text_color_class: "text-slate-700",
        city_stock_display: nil
      },
      # sulfur ————————————————————————————————————
      sulfur: %ResourceMetadata{
        title: :sulfur,
        description: "Sulfur is an essential building component of explosives",
        image_sources: ["/images/sulfur.svg"],
        text_color_class: "text-orange-700",
        city_stock_display: nil
      },
      # lithium ————————————————————————————————————
      lithium: %ResourceMetadata{
        title: :lithium,
        description: "Used to make electrical components",
        image_sources: ["/images/lithium.svg"],
        text_color_class: "text-lime-700",
        city_stock_display: nil
      },
      # fish ————————————————————————————————————
      fish: %ResourceMetadata{
        title: :fish,
        description: "Sushi material",
        image_sources: ["/images/fish.svg"],
        text_color_class: "text-cyan-700",
        city_stock_display: nil
      },
      # oil ————————————————————————————————————
      oil: %ResourceMetadata{
        title: :oil,
        description: "Liquid gold",
        image_sources: ["/images/oil.svg"],
        text_color_class: "text-stone-700",
        city_stock_display: nil
      },
      # water ————————————————————————————————————
      water: %ResourceMetadata{
        title: :water,
        description: "Liquid... liquid",
        image_sources: ["/images/water.svg"],
        text_color_class: "text-sky-700",
        city_stock_display: nil
      },
      # salt ————————————————————————————————————
      salt: %ResourceMetadata{
        title: :salt,
        description: "Used by gamers to apply on wounds",
        image_sources: ["/images/salt.svg"],
        text_color_class: "text-zinc-700",
        city_stock_display: nil
      },
      # uranium ————————————————————————————————————
      uranium: %ResourceMetadata{
        title: :uranium,
        description: "Dangerous to living things, but also contains a great power within its green crystals",
        image_sources: ["/images/uranium.svg"],
        text_color_class: "text-violet-700",
        city_stock_display: nil
      },

      # COMBAT RESOURCES ——————————————————————————————————
      # missiles ————————————————————————————————————
      missiles: %ResourceMetadata{
        title: :missiles,
        description: "Man invented things to throw and hurt one another. Let man do what he must do.",
        image_sources: ["/images/might.svg"],
        text_color_class: "text-red-700",
        city_stock_display: nil
        },
      # shields ————————————————————————————————————
      shields: %ResourceMetadata{
        title: :shields,
        description: "The defensive power of a city. A shield protects the city from an equivalent number of missiles.",
        image_sources: ["/images/shields.svg"],
        text_color_class: "text-blue-700",
        city_stock_display: nil
        },

      # SUPPLY RESOURCES ——————————————————————————————————
      ### A supply resource is usually represented as 'consumption / production'. Generally, consumption cannot exceed production, and actions that would do so are barred
      # area ————————————————————————————————————
      area: %ResourceMetadata{
        title: :area,
        description: "Area represents the land that the city can support. Generally increased by transit and infrastructure.",
        image_sources: ["/images/area.svg"],
        text_color_class: "text-cyan-700",
        city_stock_display: nil
        },
      # housing ————————————————————————————————————
      housing: %ResourceMetadata{
        title: :housing,
        description: "Housing represents the living space that the city can support. Citizens need a place to live in.",
        image_sources: ["/images/housing.svg"],
        text_color_class: "text-amber-700",
        city_stock_display: nil
        },
      # energy ————————————————————————————————————
      energy: %ResourceMetadata{
        title: :energy,
        description: "Electrical energy is used by the city's infrastructure to perform various tasks and maintain supply.",
        image_sources: ["/images/energy.svg"],
        text_color_class: "text-yellow-700",
        city_stock_display: nil
        },

      # quality_of_life RESOURCES ——————————————————————————————————
      ### A quality_of_life resource is represented as a single number. This value is non-cumulative.
      # health ————————————————————————————————————
      health: %ResourceMetadata{
        title: :health,
        description: "The overall healthcare support provided by the city. Improves birth rates and attractiveness of the city to migrating citizens.",
        image_sources: ["/images/health.svg"],
        text_color_class: "text-rose-700",
        city_stock_display: nil
      },
      # fun ————————————————————————————————————
      fun: %ResourceMetadata{
        title: :fun,
        description: "The overall entertainment value provided by the city. Improves attractiveness of the city to migrating citizens.",
        image_sources: ["/images/fun.svg"],
        text_color_class: "text-fuchsia-700",
        city_stock_display: nil
      },
      # sprawl ————————————————————————————————————
      sprawl: %ResourceMetadata{
        title: :sprawl,
        description: "As cities grow in size, so too do they become more complex and inconvenient. Train lines are longer, communte times are longer, and privacy becomes an issue. Reduces attractiveness of the city to migrating citizens.",
        image_sources: ["/images/sprawl.svg"],
        text_color_class: "text-yellow-700",
        city_stock_display: nil
      },

      # SPECIAL RESOURCES ——————————————————————————————————
      ### Mostly hidden resources that work internally
      # maintenance ————————————————————————————————————
      maintenance: %ResourceMetadata{
        title: :maintenance,
        description: "The overall cost of running the city. Takes from your treasury.",
        image_sources: ["/images/minus.svg", "/images/money-off.svg"],
        text_color_class: "text-red-700",
        city_stock_display: nil
      },
      # maintenance_costs ————————————————————————————————————
      income: %ResourceMetadata{
        title: "Income",
        description: "The daily income gained by the city. Feeds to your treasury.",
        image_sources: ["/images/plus.svg", "/images/money-fulfilled.svg"],
        text_color_class: "text-green-700",
        city_stock_display: nil
      },
      # education ————————————————————————————————————
      education: %ResourceMetadata{
        title: :education,
        description: "Education provides citizens the experience and knowledge to perform trades and specialized tasks. This in turn makes them more valuable.",
        image_sources: ["/images/education.svg"],
        text_color_class: "text-sky-700",
        city_stock_display: nil
      },
      # subtypes of education ————————————————————————————————————
      education_lvl_1: %ResourceMetadata{
        title: :education,
        image_sources: ["/images/education.svg"],
        text_color_class: "text-sky-700",
        city_stock_display: nil
      },
      education_lvl_2: %ResourceMetadata{
        title: :education,
        image_sources: ["/images/education.svg"],
        text_color_class: "text-sky-700",
        city_stock_display: nil
      },
      education_lvl_3: %ResourceMetadata{
        title: :education,
        image_sources: ["/images/education.svg"],
        text_color_class: "text-sky-700",
        city_stock_display: nil
      },
      education_lvl_4: %ResourceMetadata{
        title: :education,
        image_sources: ["/images/education.svg"],
        text_color_class: "text-sky-700",
        city_stock_display: nil
      },
      education_lvl_5: %ResourceMetadata{
        title: :education,
        image_sources: ["/images/education.svg"],
        text_color_class: "text-sky-700",
        city_stock_display: nil
      },

      # workers ————————————————————————————————————
      workers: %ResourceMetadata{
        title: :workers,
        description: "Employment provides citizens a job to sustain their lifestyle. Citizens without jobs may leave for greener pastures.",
        image_sources: ["/images/workers-fulfilled.svg"],
        text_color_class: "text-green-700",
        city_stock_display: nil
        },
    }
  end
end
