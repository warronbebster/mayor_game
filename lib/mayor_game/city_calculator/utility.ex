defmodule MayorGame.Utility do
  @doc """
  A random number from a gamma distribution with the given shape (>= 1) and scale,
  using Marsaglia & Tsang's method.
  """
  @spec gamma_variate(number, number) :: float
  def gamma_variate(shape, scale) when shape >= 1 do
    d = shape - 1 / 3
    c = 1 / :math.sqrt(9 * d)
    x = :rand.normal()
    v = :math.pow(1 + c * x, 3)

    if v > 0 and :math.log(:rand.uniform()) < 0.5 * x * x + d - d * v + d * :math.log(v),
      do: d * v * scale,
      else: gamma_variate(shape, scale)
  end

  @spec dice_roll(integer, number) :: integer
  def dice_roll(number_of_trials, probability) do
    # issue with Statistics.Distributions.Binomial as of statistics 0.6.2, raised in https://github.com/msharp/elixir-statistics/issues/30
    # for now, add a guard
    cond do
      number_of_trials == 0 -> 0
      number_of_trials == 1 -> if :rand.uniform() < probability, do: 1, else: 0
      number_of_trials > 1 -> round(Statistics.Distributions.Binomial.rand(number_of_trials, probability))
    end
  end
end
