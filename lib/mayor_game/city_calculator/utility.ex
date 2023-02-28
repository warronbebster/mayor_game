defmodule MayorGame.Utility do

  @spec dice_roll(integer, number) :: integer
  def dice_roll(number_of_trials, probability) do
    # issue with Statistics.Distributions.Binomial as of statistics 0.6.2, raised in https://github.com/msharp/elixir-statistics/issues/30
    # for now, add a guard
    cond do
      number_of_trials == 0 -> 0
      number_of_trials == 1 -> :rand.uniform() < probability
      number_of_trials > 1 -> round(Statistics.Distributions.Binomial.rand(number_of_trials, probability))
    end
  end
end
