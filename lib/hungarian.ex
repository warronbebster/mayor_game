defmodule Hungarian do
  @moduledoc """
  Written by Adam Kirk – Jan 18, 2020
  Most helpful resources used:
  https://www.youtube.com/watch?v=dQDZNHwuuOY
  https://www.youtube.com/watch?v=cQ5MsiGaDY8
  https://www.geeksforgeeks.org/hungarian-algorithm-assignment-problem-set-1-introduction/
  """

  # takes an nxn matrix of costs and returns a list of {row, column}
  # tuples of assigments that minimizes total cost
  def compute([row1 | _] = matrix) do
    matrix
    # |> IO.inspect(
    #   label: "hungarian_input_matrix",
    #   limit: :infinity,
    #   printable_limit: :infinity,
    #   pretty: true
    # )
    # add "zero" rows if its not a square matrix
    |> pad()
    # perform the calculation
    |> step()
    # remove any assignments that are in the padded matrix
    |> Enum.filter(fn {r, c} -> r < length(matrix) and c < length(row1) end)
  end

  defp step(matrix, step \\ 1, assignments \\ nil, count \\ 0)

  # match on done
  defp step(matrix, _step, assignments, _count) when length(assignments) == length(matrix),
    do: assignments

  # For each row of the matrix, find the smallest element and
  # subtract it from every element in its row. If no assignments, go step 2
  defp step(matrix, 1, _assignments, _count) do
    transformed = rows_to_zero(matrix)
    assigned = assignments(transformed)
    step(transformed, 2, assigned)
  end

  # For each column of the matrix, find the smallest element and
  # subtract it from every element in its column. If no assignments, go step 3
  defp step(matrix, 2, _assignments, _count) do
    transformed =
      matrix
      |> transpose()
      |> rows_to_zero()
      |> transpose()

    assigned = assignments(transformed)
    step(transformed, 3, assigned)
  end

  defp step(matrix, 3, _assignments, count) do
    {covered_rows, covered_cols} = min_lines(matrix)
    # IO.inspect("#{Enum.join(covered_rows, ",")} x #{Enum.join(covered_cols, ",")}")

    min_uncovered =
      matrix
      |> transform(fn {r, c}, val ->
        if c not in covered_cols and r not in covered_rows do
          val
        end
      end)
      |> List.flatten()
      |> Enum.filter(&(!is_nil(&1)))
      |> Enum.min()

    # |> IO.inspect(label: "min_uncovered")

    transformed =
      matrix
      |> transform(fn {r, c}, val ->
        case {r in covered_rows, c in covered_cols} do
          # if uncovered, subtract the min
          {false, false} -> Float.round(val - min_uncovered, 3)
          # if covered by a vertical and horizontal line, add min_uncovered
          {true, true} -> Float.round(val + min_uncovered, 3)
          # otherwise, leave it alone
          _ -> val
        end
      end)
      |> print_matrix()

    assigned = assignments(transformed)

    if count < 50 do
      step(transformed, 3, assigned, count + 1)
    else
      raise "There must be a bug in this code that can't handle the input matrix."
    end
  end

  defp assignments(matrix) do
    matrix
    |> reduce([], fn {r, c} = coord, val, acc ->
      if val == 0 do
        h_zeros = row(matrix, r) |> Enum.count(&(&1 == 0))
        v_zeros = column(matrix, c) |> Enum.count(&(&1 == 0))
        [{coord, h_zeros + v_zeros} | acc]
      else
        acc
      end
    end)
    |> Enum.sort_by(fn {_, zero_count} -> zero_count end)
    |> Enum.reduce([], fn {{r, c} = coord, _}, acc ->
      {assigned_rows, assigned_cols} = Enum.unzip(acc)

      if r not in assigned_rows && c not in assigned_cols do
        [coord | acc]
      else
        acc
      end
    end)

    # |> IO.inspect()
  end

  # https://stackoverflow.com/questions/23379660/hungarian-algorithm-finding-minimum-number-of-lines-to-cover-zeroes
  defp min_lines(matrix) do
    matrix
    # Calculate the max number of zeros vertically vs horizontally for each xy position in the input matrix
    # and store the result in a separate array called m2.
    # While calculating, if horizontal zeros > vertical zeroes, then the calculated number is converted
    # to negative. (just to distinguish which direction we chose for later use)
    |> transform(fn {r, c}, val ->
      h_zeros = row(matrix, r) |> Enum.count(&(&1 == 0))
      v_zeros = column(matrix, c) |> Enum.count(&(&1 == 0))

      cond do
        val != 0 -> 0
        h_zeros > v_zeros -> -h_zeros
        true -> v_zeros
      end
    end)
    # Loop through all elements in the m2 array. If the value is positive, draw a vertical line in array m3,
    # if value is negative, draw an horizontal line in m3
    |> reduce({[], []}, fn
      {_, c}, val, {rows, cols} when val > 0 -> {rows, [c | cols] |> Enum.uniq()}
      {r, _}, val, {rows, cols} when val < 0 -> {[r | rows] |> Enum.uniq(), cols}
      _, _, acc -> acc
    end)
  end

  defp rows_to_zero(matrix) do
    Enum.map(matrix, fn row ->
      min = Enum.min(row)

      Enum.map(row, fn column ->
        if column - min == 0, do: 0, else: Float.round(column - min, 3)
      end)
    end)
  end

  defp transpose(matrix) do
    transform(matrix, fn {r, c}, _ -> matrix |> Enum.at(c) |> Enum.at(r) end)
  end

  defp transform(matrix, func) do
    matrix
    |> Enum.with_index()
    |> Enum.map(fn {row, r} ->
      row
      |> Enum.with_index()
      |> Enum.map(fn {_column, c} ->
        func.({r, c}, matrix |> Enum.at(r) |> Enum.at(c))
      end)
    end)
  end

  def reduce(matrix, init, func) do
    matrix
    |> Enum.with_index()
    |> Enum.reduce(init, fn {row, r}, acc ->
      row
      |> Enum.with_index()
      |> Enum.reduce(acc, fn {_column, c}, acc2 ->
        func.({r, c}, matrix |> Enum.at(r) |> Enum.at(c), acc2)
      end)
    end)
  end

  defp print_matrix(matrix, opts \\ []) do
    IO.puts("#{opts[:label]}------------")

    for row <- matrix do
      row
      |> Enum.map(fn v -> truncate(v) end)
      |> Enum.join("\t")
      |> IO.puts()
    end

    matrix
  end

  defp row(matrix, index), do: Enum.at(matrix, index)
  defp column(matrix, index), do: Enum.map(matrix, &Enum.at(&1, index))

  defp pad([first | _] = matrix) do
    case length(matrix) - length(first) do
      # use the matrix only if it has the same number of columns and rows
      0 ->
        matrix

      # more rows than columns, add zero columns to each row
      diff when diff > 0 ->
        Enum.map(matrix, fn row ->
          row ++ Enum.map(1..abs(diff), fn _ -> 0 end)
        end)

      # more columns than rows, add a row of zeros
      diff when diff < 0 ->
        matrix ++ [Enum.map(1..length(matrix), fn _ -> 0 end)]
    end
  end

  defp pad(matrix), do: matrix

  defp truncate(float) do
    trunc(float * 1000) / 1000
  end
end
