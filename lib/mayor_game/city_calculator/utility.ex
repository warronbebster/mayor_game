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

  # make a string presentable by replacing underscores with spaces, and converting to title case
  # note: Erlang's 'titlecase' only converts the first letter, not first letter of each word
  # We may be able to hook to ReCase for our purposes: https://github.com/wemake-services/recase
  @spec presentable_string(any, boolean) :: String.t()
  def presentable_string(object, titlecase \\ false) do
    if titlecase do
      :string.titlecase(String.replace(to_string(object), "_", " "))
    else
      String.replace(to_string(object), "_", " ")
    end
  end
end
