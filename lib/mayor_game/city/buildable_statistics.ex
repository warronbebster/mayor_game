defmodule MayorGame.City.BuildableStatistics do
  use Accessible

  # defaults to nil for keys without values
  defstruct [
    :title,
    number: 0,
    # fulfills reqs
    operational: 0,
    in_construction: 0,
    workers_by_level: %{},
    deficient_prereq_next: [],
    deficient_prereq_all: [],
    # precalc?
    resource: %{}
  ]

  @type t :: %__MODULE__{
          title: String.t(),
          number: integer,
          operational: integer,
          in_construction: integer,
          workers_by_level: %{integer => integer},
          deficient_prereq_next: list(atom),
          deficient_prereq_all: list(atom),
          resource: %{atom => ResourceStatistics.t()}
        }
end
