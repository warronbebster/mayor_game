defmodule MayorGame.MarketHelpers do
  alias MayorGame.City.{
    Town,
    World,
    Citizens,
    ResourceStatistics,
    BuildableStatistics,
    TownStatistics,
    TownMigrationStatistics,
    OngoingSanctions
  }

  alias MayorGame.{Market, Bid, Repo}

  import Ecto.Query, warn: false

  def calculate_market_trades(leftovers_by_id) do
    markets_by_resource = Enum.group_by(Market.list_markets(), & &1.resource)
    bids_by_resource = Enum.group_by(Bid.list_bids(), & &1.resource)

    sanctions =
      Repo.all(OngoingSanctions)
      |> Repo.preload([:sanctioning, :sanctioned])

    IO.inspect(sanctions, label: "sanctions")

    # if !is_nil(markets_by_resource) do
    # if there are markets at all
    Enum.each(markets_by_resource, fn {resource_string, market_list} ->
      bid_list = bids_by_resource[resource_string]
      resource = String.to_existing_atom(resource_string)

      if !is_nil(bid_list) do
        lowest_sell_price = Enum.min_by(market_list, & &1.min_price).min_price
        highest_bid_price = Enum.max_by(bid_list, & &1.max_price).max_price

        # all markets with a min price less than the highest bid price
        potentially_valid_markets =
          market_list
          |> Enum.filter(fn market -> market.min_price <= highest_bid_price end)
          |> Enum.filter(fn market ->
            if is_nil(leftovers_by_id[market.town_id]) do
              false
            else
              TownStatistics.getResource(leftovers_by_id[market.town_id], resource).stock > 0
            end
          end)
          |> Enum.sort_by(& &1.min_price, :desc)
          |> Enum.map(fn market ->
            # actually here you want to sell the resources for the leftover cities
            available_resources = TownStatistics.getResource(leftovers_by_id[market.town_id], resource)

            if market.sell_excess && available_resources.stock > 0 do
              market |> Map.put(:amount_to_sell, available_resources.stock)
            else
              market |> Map.update!(:amount_to_sell, &min(&1, available_resources.stock))
            end
          end)

        potentially_valid_bids =
          bid_list
          |> Enum.filter(fn bid -> bid.max_price >= lowest_sell_price end)
          |> Enum.filter(fn bid ->
            if is_nil(leftovers_by_id[bid.town_id]) do
              false
            else
              resources = leftovers_by_id[bid.town_id] |> TownStatistics.getResource(resource)

              ResourceStatistics.getStorage(resources) - ResourceStatistics.getNextStock(resources) +
                ResourceStatistics.getNetProduction(resources) >= bid.amount
            end
          end)

        if !is_nil(potentially_valid_markets) && potentially_valid_markets != [] do
          # if there are any matching bids
          valid_sell_amount_sum = potentially_valid_markets |> Enum.map(& &1.amount_to_sell) |> Enum.sum()
          valid_buy_amount_sum = potentially_valid_bids |> Enum.map(& &1.amount) |> Enum.sum()

          potentially_valid_bids =
            if valid_buy_amount_sum >= valid_sell_amount_sum,
              do: potentially_valid_bids |> Enum.sort_by(& &1.max_price, :desc),
              else: potentially_valid_bids |> Enum.sort_by(& &1.max_price, :asc)

          potentially_valid_markets =
            if valid_buy_amount_sum >= valid_sell_amount_sum,
              do: potentially_valid_markets |> Enum.sort_by(& &1.min_price, :desc),
              else: potentially_valid_markets |> Enum.sort_by(& &1.min_price, :asc)

          market_match_results =
            Enum.reduce_while(
              potentially_valid_bids,
              %{markets: potentially_valid_markets, results: %{}},
              fn bid, acc ->
                if acc.markets == [] do
                  # if no more markets
                  {:halt, acc}
                else
                  paid_price = round((bid.max_price + hd(acc.markets).min_price) / 2)

                  town_money_stats = leftovers_by_id[bid.town_id] |> TownStatistics.getResource(:money)

                  {:cont,
                   if town_money_stats.stock + town_money_stats.production - town_money_stats.consumption >=
                        bid.amount * paid_price &&
                        bid.max_price > hd(acc.markets).min_price do
                     Enum.reduce_while(acc.markets, Map.put_new(acc, :bid_amount, bid.amount), fn market, acc2 ->
                       if market.amount_to_sell >= acc2.bid_amount do
                         # if enough in the top market
                         {:halt,
                          %{
                            markets: [
                              Map.update!(market, :amount_to_sell, &(&1 - acc2.bid_amount)) | tl(acc2.markets)
                            ],
                            results:
                              acc2.results
                              |> Map.update(
                                bid.town_id,
                                %{:money => -paid_price * acc2.bid_amount, resource => acc2.bid_amount},
                                fn existing_results ->
                                  existing_results
                                  |> Map.update!(:money, &(&1 - paid_price * acc2.bid_amount))
                                  |> Map.update(resource, acc2.bid_amount, &(&1 + acc2.bid_amount))
                                end
                              )
                              |> Map.update(
                                market.town_id,
                                %{:money => paid_price * acc2.bid_amount, resource => -acc2.bid_amount},
                                fn existing_results ->
                                  existing_results
                                  |> Map.update!(:money, &(&1 + paid_price * acc2.bid_amount))
                                  |> Map.update(resource, acc2.bid_amount, &(&1 - acc2.bid_amount))
                                end
                              )
                          }}
                       else
                         # if not enough
                         {:cont,
                          %{
                            markets: tl(acc2.markets),
                            bid_amount: acc2.bid_amount - market.amount_to_sell,
                            results:
                              acc2.results
                              |> Map.update(
                                bid.town_id,
                                %{:money => -paid_price * market.amount_to_sell, resource => market.amount_to_sell},
                                fn existing_results ->
                                  existing_results
                                  |> Map.update!(:money, &(&1 - paid_price * market.amount_to_sell))
                                  |> Map.update(resource, market.amount_to_sell, &(&1 + market.amount_to_sell))
                                end
                              )
                              |> Map.update(
                                market.town_id,
                                %{:money => paid_price * market.amount_to_sell, resource => -market.amount_to_sell},
                                fn existing_results ->
                                  existing_results
                                  |> Map.update!(:money, &(&1 + paid_price * market.amount_to_sell))
                                  |> Map.update(resource, market.amount_to_sell, &(&1 - market.amount_to_sell))
                                end
                              )
                          }}
                       end
                     end)
                   else
                     # if city doesn't have enough money
                     acc
                   end}
                end
              end
            )

          # IO.inspect(market_match_results.results)
          # shape is like this
          # %{2 => %{money: 6, stone: -1}, 20 => %{money: -6, stone: 1}}
          # so this is where I could add logs

          market_match_results.results
          |> Enum.chunk_every(200)
          |> Enum.each(fn chunk ->
            Repo.checkout(fn ->
              # town_ids = Enum.map(chunk, fn city -> city.id end)
              Enum.each(chunk, fn {city_id, resource_map} ->
                # I think I could clean this up to only do one repo update per city instead of one per resource

                to_inc =
                  resource_map
                  |> Enum.map(fn {key, value} ->
                    updated_key = if key == :money, do: :treasury, else: key
                    {updated_key, value}
                  end)

                logs_market_sales = leftovers_by_id[city_id].logs_market_sales
                logs_market_purchases = leftovers_by_id[city_id].logs_market_purchases

                new_sales =
                  to_inc
                  |> Keyword.drop([:treasury])
                  |> Keyword.filter(fn {_k, v} -> v < 0 end)

                new_purchases =
                  to_inc
                  |> Keyword.drop([:treasury])
                  |> Keyword.filter(fn {_k, v} -> v > 0 end)

                new_sales_logs =
                  Enum.reduce(new_sales, logs_market_sales, fn {k, v}, acc ->
                    Map.update(acc, to_string(k), -v, &(&1 - v))
                  end)

                new_purchases_logs =
                  Enum.reduce(new_purchases, logs_market_purchases, fn {k, v}, acc ->
                    Map.update(acc, to_string(k), v, &(&1 + v))
                  end)

                to_set = [logs_market_sales: new_sales_logs, logs_market_purchases: new_purchases_logs]

                from(t in Town, where: [id: ^city_id])
                |> Repo.update_all(inc: to_inc, set: to_set)
              end)
            end)
          end)

          # if there are bids and markets for the given resource
          # active_sell_list = all sell-offers <= highest bid
          # active_bid_list = all bids >= lowest sell-offer

          # if active_sell_list is shorter, match bids/sales from high-to-low, and ignore any excess bids (first image)
          # if active_bid_list is shorter, match bids/sales from low-to-high and ignore any excess sales
          # if they're equal than it doesn't matter, just match them (third image)

          # reduce potentially valid markets and potentially valid bids (and maybe leftovers?)
          # check if the city has enough moneyyy
          # if so, make transfer (or just accumulate in leftovers? or a new accumulator?), subtract amount from city
          # if amount is more than market or bid, subtract that bid from the list, but otherwise subtract the amount from the other
          # accumulate, per city
        end
      end
    end)

    # end

    # if there are bids but no market, you can ignore them
    # also if there are markets but no bids, you can ignore them
    # output should be logs, but also just correctly incrementing each city
  end
end
