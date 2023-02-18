defmodule MayorGame.City.Resource do
    alias MayorGame.City.{ResourceMetadata}
    use Accessible
       
    def resource_category_descriptions do
      %{
        stored:
          "These resources are typically accumulated by the city. Some of these resources may be associated with a storage maximum",
        supplied:
          "These resources are typically supplied and consumed in the city. Generally, consumption will not excced supply",
        metered:
          "These resources represent a city's attribute. These metrics may be used by citizens to determine their preferred cities",
        special: 
          "These buildings have special purposes, or have unique mechanics to aid the city's daily functions",
      }
    end

    def resources do
      %{
        stored: [
          pollution: resources_flat().pollution,
          money: resources_flat().money,
          steel: resources_flat().steel,
          sulfur: resources_flat().sulfur,
          uranium: resources_flat().uranium,
          missiles: resources_flat().missiles,
          shields: resources_flat().shields,
        ],
        supplied: [
          area: resources_flat().area,
          housing: resources_flat().housing,
          energy: resources_flat().energy,
        ],
        metered: [
          health: resources_flat().health,
          fun: resources_flat().fun,
          sprawl: resources_flat().sprawl,
        ],
        special: [
          education: resources_flat().education,
          workers: resources_flat().workers,
        ],
      }
    end
  
    def resources_kw_list do
      [
        stored: [
          pollution: resources_flat().pollution,
          money: resources_flat().money,
          steel: resources_flat().steel,
          sulfur: resources_flat().sulfur,
          uranium: resources_flat().uranium,
          missiles: resources_flat().missiles,
          shields: resources_flat().shields,
        ],
        supplied: [
          area: resources_flat().area,
          housing: resources_flat().housing,
          energy: resources_flat().energy,
        ],
        metered: [
          health: resources_flat().health,
          fun: resources_flat().fun,
          sprawl: resources_flat().sprawl,
        ],
        special: [
          education: resources_flat().education,
          workers: resources_flat().workers,
        ],
      ]
    end
  
    def resources_flat do
      %{
        # STORED RESOURCES ——————————————————————————————————
        ### A stored resource is usually represented as 'amount', or if limited storage is implemented, 'amount / storage'. Generally, resources in excess of storage are wasted and removed
        # pollution ————————————————————————————————————
        pollution: %ResourceMetadata{
          category: :stored,
          title: :pollution,
          description: "The elephant in the room. The world can only take so much pollution before its ability to sustain life is affected.",
          image_source: "/images/pollution.svg",
          text_color_class: "text-purple-800"
        },
        # money ————————————————————————————————————
        money: %ResourceMetadata{
          category: :stored,
          title: :money,
          description: "Money makes the world go round~",
          image_source: "/images/money-fulfilled.svg",
          text_color_class: "text-green-800"
        },
        # steel ————————————————————————————————————
        steel: %ResourceMetadata{
          category: :stored,
          title: :steel,
          description: "Steel is an essential building component of other resources",
          image_source: "/images/steel.svg",
          text_color_class: "text-slate-700"
        },
        # sulfur ————————————————————————————————————
        sulfur: %ResourceMetadata{
          category: :stored,
          title: :sulfur,
          description: "Sulfur is an essential building component of explosives",
          image_source: "/images/sulfur.svg",
          text_color_class: "text-orange-700"
        },
        # uranium ————————————————————————————————————
        uranium: %ResourceMetadata{
          category: :stored,
          title: :uranium,
          description: "Dangerous to living things, but also contains a great power within its green crystals",
          image_source: nil,
          text_color_class: "text-green-600"
        },
        # missiles ————————————————————————————————————
        missiles: %ResourceMetadata{
          category: :stored,
          title: :missiles,
          description: "Man invented things to throw and hurt one another. Let man do what he must do.",
          image_source: "/images/might.svg",
          text_color_class: "text-red-600"
        },
        # shields ————————————————————————————————————
        shields: %ResourceMetadata{
          category: :stored,
          title: :shields,
          description: "The defensive power of a city. A shield protects the city from an equivalent number of missiles.",
          image_source: "/images/shields.svg",
          text_color_class: "text-blue-600"
        },

        # SUPPLY RESOURCES ——————————————————————————————————
        ### A supply resource is usually represented as 'consumption / production'. Generally, consumption cannot exceed production, and actions that would do so are barred
        # area ————————————————————————————————————
        area: %ResourceMetadata{
          category: :supplied,
          title: :area,
          description: "Area represents the land that the city can support. Generally increased by transit and infrastructure.",
          image_source: "/images/area.svg",
          text_color_class: "text-cyan-700"
        },
        # housing ————————————————————————————————————
        housing: %ResourceMetadata{
          category: :supplied,
          title: :housing,
          description: "Housing represents the living space that the city can support. Citizens need a place to live in.",
          image_source: "/images/housing.svg",
          text_color_class: "text-amber-700"
        },
        # energy ————————————————————————————————————
        energy: %ResourceMetadata{
          category: :supplied,
          title: :energy,
          description: "Electrical energy is used by the city's infrastructure to perform various tasks and maintain supply.",
          image_source: "/images/energy.svg",
          text_color_class: "text-yellow-700"
        },

        # METERED RESOURCES ——————————————————————————————————
        ### A metered resource is represented as a single number. This value is non-cumulative.
        # health ————————————————————————————————————
        health: %ResourceMetadata{
          category: :metered,
          title: :health,
          description: "The overall healthcare support provided by the city. Improves birth rates and attractiveness of the city to migrating citizens.",
          image_source: "/images/health.svg",
          text_color_class: "text-rose-700"
        },
        # fun ————————————————————————————————————
        fun: %ResourceMetadata{
          category: :metered,
          title: :fun,
          description: "The overall entertainment value provided by the city. Improves attractiveness of the city to migrating citizens.",
          image_source: "/images/fun.svg",
          text_color_class: "text-fuchsia-700"
        },
        # sprawl ————————————————————————————————————
        sprawl: %ResourceMetadata{
          category: :metered,
          title: :sprawl,
          description: "As cities grow in size, so too do they become more complex and inconvenient. Train lines are longer, communte times are longer, and privacy becomes an issue. Reduces attractiveness of the city to migrating citizens.",
          image_source: nil,
          text_color_class: "text-gray-700"
        },

        # education ————————————————————————————————————
        education: %ResourceMetadata{
          category: :special,
          title: :education,
          description: "Education provides citizens the experience and knowledge to perform trades and specialized tasks. This in turn makes them more valuable.",
          image_source: nil,
          text_color_class: "text-blue-800"
        },

        # workers ————————————————————————————————————
        workers: %ResourceMetadata{
          category: :special,
          title: :workers,
          description: "Employment provides citizens a job to sustain their lifestyle. Citizens without jobs may leave for greener pastures.",
          image_source: "/images/workers-fulfilled.svg",
          text_color_class: "text-green-700"
        },
      }
    end
  end
  