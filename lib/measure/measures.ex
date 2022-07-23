# SPDX-License-Identifier: AGPL-3.0-only
defmodule Bonfire.Quantify.Measures do
  import Where
  alias Bonfire.Common.Utils
  alias Bonfire.Quantify.{Measure, Unit, Units}
  alias Bonfire.Quantify.Measures.Queries

  @user Application.compile_env!(:bonfire, :user_schema)
  import Bonfire.Common.Config, only: [repo: 0]

  def federation_module, do: ["Measure", "om2:Measure"]

  def cursor(), do: &[&1.id]
  def test_cursor(), do: &[&1["id"]]

  @doc """
  Retrieves a single collection by arbitrary filters.
  Used by:
  * GraphQL Item queries
  * ActivityPub integration
  * Various parts of the codebase that need to query for collections (inc. tests)
  """
  def one(filters), do: repo().single(Queries.query(Measure, filters))

  @doc """
  Retrieves a list of collections by arbitrary filters.
  Used by:
  * Various parts of the codebase that need to query for collections (inc. tests)
  """
  def many(filters \\ []), do: {:ok, repo().many(Queries.query(Measure, filters))}


  ## mutations

  @spec create(any(), Unit.t(), attrs :: map) :: {:ok, Measure.t()} | {:error, Changeset.t()}
  def create(creator, %Unit{} = unit, attrs) when is_map(attrs) do
    repo().transact_with(fn ->
      with {:ok, item} <- insert_measure(creator, unit, attrs) do
        Utils.maybe_apply(Bonfire.Social.Objects, :publish, [creator, :create, item, attrs, __MODULE__]) # FIXME: use publishing logic in from a different repo
        {:ok, %{item | unit: unit}}
      end
    end)
  end
  def create(creator, maybe_unit, attrs) when is_map(attrs) do
    with {:ok, unit} <- Units.get_or_create(maybe_unit, creator) do
      create(creator, unit, attrs)
    else _ ->
      raise {:error, "Invalid unit"}
    end
  end

  def create(creator, %{unit: unit} = attrs) when is_map(attrs) do
    create(creator, unit, attrs)
  end
  def create(creator, %{has_unit: unit} = attrs) when is_map(attrs) do
    create(creator, unit, attrs)
  end

  defp insert_measure(creator, unit, attrs) do
    # TODO: use insert_or_ignore?
    # TODO: should we re-use the same measurement instead of storing duplicates? (but would have to be careful to insert a new measurement rather than update)
    repo().insert(Bonfire.Quantify.Measure.create_changeset(creator, unit, attrs)
      # on_conflict: [set: [has_numerical_value: attrs.has_numerical_value]]
    )
  end

  # TODO: take the user who is performing the update
  @spec update(Measure.t(), attrs :: map) :: {:ok, Measure.t()} | {:error, Changeset.t()}
  def update(%Measure{} = measure, attrs) do
    repo().transact_with(fn ->
      with {:ok, measure} <- repo().update(Measure.update_changeset(measure, attrs)) do
        #  :ok <- publish(measure, :updated) do
        {:ok, measure}
      end
    end)
  end

  # def soft_delete(%Measure{} = measure) do
  #   repo().transact_with(fn ->
  #     with {:ok, measure} <- Bonfire.Common.Repo.Delete.soft_delete(measure),
  #          :ok <- publish(measure, :deleted) do
  #       {:ok, measure}
  #     end
  #   end)
  # end

  def ap_publish_activity(activity_name, thing) do
    ValueFlows.Util.Federation.ap_publish_activity(activity_name, :measure, thing, 2, [
    ])
  end

  def ap_receive_activity(creator, activity, object) do
    ValueFlows.Util.Federation.ap_receive_activity(creator, activity, object, &create/2)
  end

end
