# SPDX-License-Identifier: AGPL-3.0-only
if Code.ensure_loaded?(Bonfire.GraphQL) do
defmodule Bonfire.Quantify.Measures.GraphQL do
  use Absinthe.Schema.Notation

  alias Bonfire.GraphQL

  alias Bonfire.GraphQL.{
    ResolveField,
    ResolveFields,
    # ResolvePage,
    # ResolvePages,
    ResolveRootPage,
    FetchPage,
    # FetchPages,
    FetchFields,
    Fields, Page, Pagination
  }

  alias Bonfire.Quantify.Measure
  alias Bonfire.Quantify.Measures
  alias Bonfire.Quantify.Measures.Queries

  alias Bonfire.Quantify.Units

  import Bonfire.Common.Config, only: [repo: 0]

  def fields(group_fn, filters \\ [])
      when is_function(group_fn, 1) do
    {:ok, fields} = Measures.many(filters)
    {:ok, Fields.new(fields, group_fn)}
  end

  @doc """
  Retrieves an Page of units according to various filters

  Used by:
  * GraphQL resolver single-parent resolution
  """
  def page(cursor_fn, page_opts, base_filters \\ [], data_filters \\ [], count_filters \\ [])

  def page(cursor_fn, %{} = page_opts, base_filters, data_filters, count_filters) do
    base_q = Queries.query(Measure, base_filters)
    data_q = Queries.filter(base_q, data_filters)
    count_q = Queries.filter(base_q, count_filters)

    with {:ok, [data, counts]} <- repo().transact_many(all: data_q, count: count_q) do
      {:ok, Page.new(data, counts, cursor_fn, page_opts)}
    end
  end

  @doc """
  Retrieves an Pages of units according to various filters

  Used by:
  * GraphQL resolver bulk resolution
  """
  def pages(
        cursor_fn,
        group_fn,
        page_opts,
        base_filters \\ [],
        data_filters \\ [],
        count_filters \\ []
      )

  def pages(cursor_fn, group_fn, page_opts, base_filters, data_filters, count_filters) do
    Pagination.pages(
      Queries,
      Measure,
      cursor_fn,
      group_fn,
      page_opts,
      base_filters,
      data_filters,
      count_filters
    )
  end

  # resolvers

  def measure(%{id: id}, info) do
    ResolveField.run(%ResolveField{
      module: __MODULE__,
      fetcher: :fetch_measure,
      context: id,
      info: info
    })
  end

  def measures_pages(page_opts, info) do
    ResolveRootPage.run(%ResolveRootPage{
      module: __MODULE__,
      fetcher: :fetch_measures,
      page_opts: page_opts,
      info: info,
      cursor_validators: [&(is_integer(&1) and &1 >= 0), &Pointers.ULID.cast/1]
    })
  end

  # fetchers

  def fetch_measure(info, id) do
    Measures.one([
      :default,
      user: GraphQL.current_user(info),
      id: id
    ])
  end

  def fetch_measures(page_opts, info) do
    FetchPage.run(%FetchPage{
      queries: Bonfire.Quantify.Measures.Queries,
      query: Bonfire.Quantify.Measure,
      cursor_fn:  & &1.id,
      page_opts: page_opts,
      base_filters: [user: GraphQL.current_user(info)],
      data_filters: [:default]
    })
  end

  def has_unit_edge(%{unit_id: id}, _, info) do
    ResolveFields.run(%ResolveFields{
      module: __MODULE__,
      fetcher: :fetch_has_unit_edge,
      context: id,
      info: info
    })
  end

  def has_unit_edge(_, _, _info) do
    {:ok, nil}
  end

  def fetch_has_unit_edge(_, ids) do
    FetchFields.run(%FetchFields{
      queries: Bonfire.Quantify.Units.Queries,
      query: Bonfire.Quantify.Unit,
      group_fn: & &1.id,
      filters: [:deleted, :private, id: ids]
    })
  end

  # mutations

  def create_measures(attrs, info, fields) do
    repo().transact_with(fn ->
      attrs
      |> Map.take(fields)
      |> map_ok_error(&create_measure(&1, info))
    end)
  end

  def update_measures(attrs, info, fields) do
    repo().transact_with(fn ->
      attrs
      |> Map.take(fields)
      |> map_ok_error(fn
        %{id: id} = measure when is_binary(id) ->
          update_measure(measure, info)

        measure ->
          create_measure(measure, info)
      end)
    end)
  end

  # TODO: move to a generic module
  @doc """
  Iterate over a set of elements in a map calling `func`.

  `func` is expected to return either one of `{:ok, val}` or `{:error, reason}`.
  If `{:error, reason}` is returned, iteration halts.
  """
  @spec map_ok_error(items, func) :: {:ok, any} | {:error, term}
        when items: [Map.t()],
             func: (Map.t(), any -> {:ok, any} | {:error, term})
  def map_ok_error(items, func) do
    Enum.reduce_while(items, %{}, fn {field_name, item}, acc ->
      case func.(item) do
        {:ok, val} ->
          {:cont, Map.put(acc, field_name, val)}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:error, _} = e -> e
      val -> {:ok, Enum.into(val, %{})}
    end
  end

  def create_measure(%{has_unit: unit_id} = attrs, info) do
    repo().transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, unit} <- Units.one(user: user, id: unit_id),
           {:ok, measure} <- Measures.create(user, unit, attrs) do
        {:ok, %{measure | unit: unit, creator: user}}
      end
    end)
  end

  def update_measure(%{id: id} = changes, info) do
    repo().transact_with(fn ->
      with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
           {:ok, measure} <- measure(%{id: id}, info) do
        cond do
          Bonfire.Quantify.Integration.is_admin(user) ->
            {:ok, m} = Measures.update(measure, changes)
            {:ok, %{measure: m}}

          measure.creator_id == user.id ->
            {:ok, m} = Measures.update(measure, changes)
            {:ok, %{measure: m}}

          true ->
            GraphQL.not_permitted("update")
        end
      end
    end)
  end
end
end
