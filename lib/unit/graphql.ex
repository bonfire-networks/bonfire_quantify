# SPDX-License-Identifier: AGPL-3.0-only
if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled and
     Code.ensure_loaded?(Absinthe.Schema.Notation) do
  defmodule Bonfire.Quantify.Units.GraphQL do
    use Absinthe.Schema.Notation
    import Untangle
    import Bonfire.Common.Utils

    alias Bonfire.API.GraphQL

    # CommonResolver,
    alias Bonfire.API.GraphQL.ResolveField
    # ResolveFields,
    # ResolvePage,
    # ResolvePages,
    alias Bonfire.API.GraphQL.ResolveRootPage
    alias Bonfire.API.GraphQL.FetchPage
    # FetchPages,
    alias Bonfire.API.GraphQL.Fields
    alias Bonfire.API.GraphQL.Page
    alias Bonfire.API.GraphQL.Pagination

    alias Bonfire.Quantify.Unit
    alias Bonfire.Quantify.Units
    alias Bonfire.Quantify.Units.Queries
    alias Bonfire.Quantify.Measures

    import Bonfire.Common.Config, only: [repo: 0]
    @schema_file "lib/measurement.gql"

    @external_resource @schema_file

    import_sdl(path: @schema_file)

    def fields(group_fn, filters \\ [])
        when is_function(group_fn, 1) do
      {:ok, fields} = Units.many(filters)
      {:ok, Fields.new(fields, group_fn)}
    end

    @doc """
    Retrieves an Page of units according to various filters

    Used by:
    * GraphQL resolver single-parent resolution
    """
    def page(
          cursor_fn,
          page_opts,
          base_filters \\ [],
          data_filters \\ [],
          count_filters \\ []
        )

    def page(
          cursor_fn,
          %{} = page_opts,
          base_filters,
          data_filters,
          count_filters
        ) do
      base_q = Queries.query(Unit, base_filters)
      data_q = Queries.filter(base_q, data_filters)
      count_q = Queries.filter(base_q, count_filters)

      with {:ok, [data, counts]} <-
             repo().transact_many(all: data_q, count: count_q) do
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

    def pages(
          cursor_fn,
          group_fn,
          page_opts,
          base_filters,
          data_filters,
          count_filters
        ) do
      Pagination.pages(
        Queries,
        Unit,
        cursor_fn,
        group_fn,
        page_opts,
        base_filters,
        data_filters,
        count_filters
      )
    end

    ## resolvers

    def unit(%{id: id}, info) do
      ResolveField.run(%ResolveField{
        module: __MODULE__,
        fetcher: :fetch_unit,
        context: id,
        info: info
      })
    end

    def all_units(_, _) do
      {:error, "Use unitsPages instead."}
    end

    def units(page_opts, info) do
      ResolveRootPage.run(%ResolveRootPage{
        module: __MODULE__,
        fetcher: :fetch_units,
        page_opts: page_opts,
        info: info,
        # popularity
        cursor_validators: [
          &(is_integer(&1) and &1 >= 0),
          &Needle.UID.cast/1
        ]
      })
    end

    ## fetchers

    def fetch_unit(info, id) do
      Units.one([
        :default,
        user: GraphQL.current_user(info),
        id: id
      ])
    end

    # FIXME
    def fetch_units(page_opts, info) do
      FetchPage.run(%FetchPage{
        queries: Queries,
        query: Unit,
        cursor_fn: & &1.id,
        page_opts: page_opts,
        base_filters: [:default, user: GraphQL.current_user(info)]
      })
    end

    def create_unit(%{unit: %{in_scope_of: context_id} = attrs}, info) do
      attrs = Map.merge(attrs, %{is_public: true})

      repo().transact_with(fn ->
        with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
             {:ok, context} <-
               Bonfire.Common.Needles.get(context_id, current_user: user),
             :ok <- validate_unit_context(context),
             {:ok, unit} <- Units.create(user, context, attrs) do
          {:ok, %{unit: unit}}
        end
      end)
    end

    # without context/scope
    def create_unit(%{unit: attrs} = _params, info) do
      repo().transact_with(fn ->
        with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
             attrs = Map.merge(attrs, %{is_public: true}),
             {:ok, unit} <- Units.create(user, attrs) do
          {:ok, %{unit: unit}}
        end
      end)
    end

    def update_unit(%{unit: %{id: id} = changes}, info) do
      repo().transact_with(fn ->
        with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
             {:ok, unit} <- unit(%{id: id}, info) do
          cond do
            maybe_apply(Bonfire.Me.Accounts, :is_admin?, [user], fallback_return: nil) == true ->
              {:ok, u} = Units.update(unit, changes)
              {:ok, %{unit: u}}

            unit.creator_id == user.id ->
              {:ok, u} = Units.update(unit, changes)
              {:ok, %{unit: u}}

            true ->
              GraphQL.not_permitted("to update this")
          end
        end
      end)
    end

    def delete_unit(%{id: id}, info) do
      repo().transact_with(fn ->
        with {:ok, user} <- GraphQL.current_user_or_not_logged_in(info),
             {:ok, unit} <- unit(%{id: id}, info) do
          if allow_delete?(user, unit) do
            with {:ok, _} <- Units.soft_delete(unit) do
              {:ok, true}
            end
          else
            GraphQL.not_permitted("to delete this")
          end
        end
      end)
    end

    defp allow_delete?(user, unit) do
      not dependent_measures?(unit) and allow_user_delete?(user, unit)
    end

    defp allow_user_delete?(user, unit) do
      maybe_apply(Bonfire.Me.Accounts, :is_admin?, [user], fallback_return: nil) == true or
        unit.creator_id == user.id
    end

    # TODO: provide a more helpful error message
    defp dependent_measures?(%Unit{id: unit_id} = unit) do
      {:ok, measures} = Measures.many([:default, group_count: :unit_id, unit: unit])

      n_measures =
        case measures do
          [{^unit_id, n_measures}] -> n_measures
          [] -> 0
        end

      n_measures > 0
    end

    # TEMP
    # def all_units(_, _, _) do
    #   {:ok, long_list(&Simulate.unit/0)}
    # end

    # def a_unit(%{id: id}, info) do
    #   {:ok, Simulate.unit()}
    # end
    # context validation

    defp validate_unit_context(pointer) do
      type = pointer.__struct__
      valid_contexts = valid_contexts()

      if :any in valid_contexts or type in valid_contexts do
        :ok
      else
        GraphQL.not_permitted("in_scope_of: #{type}")
      end
    end

    defp valid_contexts do
      Bonfire.Common.Config.get_ext!(:bonfire_quantify, [Units, :valid_contexts])
    end
  end
else
  IO.warn("Skip GraphQL API")
end
