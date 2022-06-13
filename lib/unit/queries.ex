# SPDX-License-Identifier: AGPL-3.0-only
defmodule Bonfire.Quantify.Units.Queries do
  import Bonfire.Common.Repo.Utils, only: [match_admin: 0]
  import Ecto.Query

  alias Bonfire.Quantify.Unit

  # alias Bonfire.Quantify.Units
  # alias CommonsPub.Follows.{
  #   Follow
  #   # FollowerCount
  # }

  # alias CommonsPub.Users

  @user Application.compile_env!(:bonfire, :user_schema)

  def query(Unit) do
    from(c in Unit, as: :unit)
  end

  def query(:count) do
    from(c in Unit, as: :unit)
  end

  def query(filters), do: query(Unit, filters)

  def query(q, filters), do: filter(query(q), filters)

  def queries(query, _page_opts, base_filters, data_filters, count_filters) do
    base_q = query(query, base_filters)
    data_q = filter(base_q, data_filters)
    count_q = filter(base_q, count_filters)
    {data_q, count_q}
  end

  def join_to(q, spec, join_qualifier \\ :left)

  def join_to(q, specs, jq) when is_list(specs) do
    Enum.reduce(specs, q, &join_to(&2, &1, jq))
  end

  def join_to(q, :context, jq) do
    join(q, jq, [unit: c], c2 in assoc(c, :context), as: :context)
  end

  # def join_to(q, {:context_follow, follower_id}, jq) do
  #   join(q, jq, [context: c], f in Follow,
  #     as: :context_follow,
  #     on: c.id == f.context_id and f.creator_id == ^follower_id
  #   )
  # end

  # def join_to(q, {:follow, follower_id}, jq) do
  #   join(q, jq, [unit: c], f in Follow,
  #     as: :follow,
  #     on: c.id == f.context_id and f.creator_id == ^follower_id
  #   )
  # end

  # def join_to(q, :follower_count, jq) do
  #   join q, jq, [unit: c],
  #     f in FollowerCount, on: c.id == f.context_id,
  #     as: :follower_count
  # end

  ### filter/2

  ## by many

  def filter(q, filters) when is_list(filters) do
    Enum.reduce(filters, q, &filter(&2, &1))
  end

  ## by preset

  def filter(q, :default) do
    filter(q, [:deleted])
  end

  ## by join

  def filter(q, {:join, {join, qual}}), do: join_to(q, join, qual)
  def filter(q, {:join, join}), do: join_to(q, join)

  ## by user

  def filter(q, {:user, match_admin()}), do: q
  def filter(q, {:user, nil}), do: filter(q, ~w(disabled private)a)

  # def filter(q, {:user, %{id: id}}) do
  #   q
  #   |> join_to(follow: id)
  #   |> where([unit: c, follow: f], not is_nil(c.published_at) or not is_nil(f.id))
  #   |> filter(~w(disabled)a)
  # end

  def filter(q, {:user, %{id: _id}}) do
    q
    |> where([unit: c], not is_nil(c.published_at))
    |> filter(~w(disabled)a)
  end


  ## by status

  def filter(q, :deleted) do
    where(q, [unit: c], is_nil(c.deleted_at))
  end

  def filter(q, :disabled) do
    where(q, [unit: c], is_nil(c.disabled_at))
  end

  def filter(q, :private) do
    where(q, [unit: c], not is_nil(c.published_at))
  end

  ## by field values

  def filter(q, {:cursor, [count, id]})
      when is_integer(count) and is_binary(id) do
    where(
      q,
      [unit: c, follower_count: fc],
      (fc.count == ^count and c.id >= ^id) or fc.count > ^count
    )
  end

  def filter(q, {:cursor, [count, id]})
      when is_integer(count) and is_binary(id) do
    where(
      q,
      [unit: c, follower_count: fc],
      (fc.count == ^count and c.id <= ^id) or fc.count < ^count
    )
  end

  def filter(q, {:id, id}) when is_binary(id) do
    where(q, [unit: c], c.id == ^id)
  end

  def filter(q, {:id, ids}) when is_list(ids) do
    where(q, [unit: c], c.id in ^ids)
  end

  def filter(q, {:label, label}) when is_binary(label) do
    where(q, [unit: c], c.label == ^label)
  end

  def filter(q, {:symbol, symbol}) when is_binary(symbol) do
    where(q, [unit: c], c.symbol == ^symbol)
  end

  def filter(q, {:label_or_symbol, search}) when is_binary(search) do
    where(q, [unit: c], c.label == ^search or c.symbol == ^search)
  end

  def filter(q, {:context_id, id}) when is_binary(id) do
    where(q, [unit: c], c.context_id == ^id)
  end

  def filter(q, {:context_id, ids}) when is_list(ids) do
    where(q, [unit: c], c.context_id in ^ids)
  end

  ## by ordering

  def filter(q, {:order, :id}) do
    filter(q, order: [desc: :id])
  end

  def filter(q, {:order, [desc: :id]}) do
    order_by(q, [unit: c, id: id],
      desc: coalesce(id.count, 0),
      desc: c.id
    )
  end

  # grouping and counting

  def filter(q, {:group_count, key}) when is_atom(key) do
    filter(q, group: key, count: key)
  end

  def filter(q, {:group, key}) when is_atom(key) do
    group_by(q, [unit: c], field(c, ^key))
  end

  def filter(q, {:count, key}) when is_atom(key) do
    select(q, [unit: c], {field(c, ^key), count(c.id)})
  end

  # pagination

  def filter(q, {:limit, limit}) do
    limit(q, ^limit)
  end

  def filter(q, {:paginate_id, %{after: a, limit: limit}}) do
    limit = limit + 2

    q
    |> where([unit: c], c.id >= ^a)
    |> limit(^limit)
  end

  def filter(q, {:paginate_id, %{before: b, limit: limit}}) do
    q
    |> where([unit: c], c.id <= ^b)
    |> filter(limit: limit + 2)
  end

  def filter(q, {:paginate_id, %{limit: limit}}) do
    filter(q, limit: limit + 1)
  end

  # def filter(q, {:page, [desc: [followers: page_opts]]}) do
  #   q
  #   |> filter(join: :follower_count, order: [desc: :followers])
  #   |> page(page_opts, [desc: :followers])
  #   |> select(
  #     [unit: c,  follower_count: fc],
  #     %{c | follower_count: coalesce(fc.count, 0)}
  #   )
  # end

  # defp page(q, %{after: cursor, limit: limit}, [desc: :followers]) do
  #   filter q, cursor: [followers: {:lte, cursor}], limit: limit + 2
  # end

  # defp page(q, %{before: cursor, limit: limit}, [desc: :followers]) do
  #   filter q, cursor: [followers: {:gte, cursor}], limit: limit + 2
  # end

  # defp page(q, %{limit: limit}, _), do: filter(q, limit: limit + 1)
end
