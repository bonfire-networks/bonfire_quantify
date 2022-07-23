# SPDX-License-Identifier: AGPL-3.0-only
defmodule Bonfire.Quantify.Units do
  import Where
  alias Bonfire.Common.Utils
  alias Bonfire.Quantify.Unit
  alias Bonfire.Quantify.Units.Queries

  import Bonfire.Common.Config, only: [repo: 0]
  @user Application.compile_env!(:bonfire, :user_schema)

  def federation_module, do: ["Unit", "om2:Unit"]

  def cursor(), do: &[&1.id]
  def test_cursor(), do: &[&1["id"]]

  @doc """
  Retrieves a single collection by arbitrary filters.
  Used by:
  * Item queries
  * ActivityPub integration
  * Various parts of the codebase that need to query for collections (inc. tests)
  """
  def one(filters), do: repo().single(Queries.query(Unit, filters))

  @doc """
  Retrieves a list of collections by arbitrary filters.
  Used by:
  * Various parts of the codebase that need to query for collections (inc. tests)
  """
  def many(filters \\ []), do: {:ok, repo().many(Queries.query(Unit, filters))}


  def get_or_create(unit, user \\ nil)

  def get_or_create(unit, user ) when is_binary(unit) do

    unit = case Process.get("uri_object:#{unit}", false) do # during federation we store nested objects like Units in the Process dictionary for re-use
      false -> nil
      nested_object ->
        info(nested_object, "retrieved Unit from Process dict")
        {:ok, nested_object}
    end

    with {:error, _} <- unit || one(label_or_symbol: unit),
    {:error, e} <- Bonfire.Quantify.Units.create(user, %{label: unit, symbol: unit}) do

      error(e)
      nil

    else {:ok, unit} ->
      {:ok, unit}
    end
  end

  def get_or_create(%{canonical_url: id, label: label, symbol: symbol} = unit, user ) do
     # TODO: lookup by canonicalURL for federated units
    with {:error, _} <- one(symbol: symbol),
    {:error, _} <- one(label: label),
    {:error, e} <- Bonfire.Quantify.Units.create(user, %{label: label, symbol: symbol}) do

      error(e)
      nil

    else {:ok, unit} ->
      {:ok, unit}
    end
  end

  ## mutations

  @spec create(any(), attrs :: map) :: {:ok, Unit.t()} | {:error, Changeset.t()}
  def create(creator, attrs) when is_map(attrs) do
    #
    repo().transact_with(fn ->
      with {:ok, unit} <- insert_unit(creator, attrs) do
        Utils.maybe_apply(Bonfire.Social.Objects, :publish, [creator, :create, unit, attrs, __MODULE__])
        {:ok, unit}
      end
    end)
  end

  @spec create(any(), context :: any, attrs :: map) ::
          {:ok, Unit.t()} | {:error, Changeset.t()}
  def create(creator, context, attrs) when is_map(attrs) do
    repo().transact_with(fn ->
      with {:ok, unit} <- insert_unit(creator, context, attrs) do
        Utils.maybe_apply(Bonfire.Social.Objects, :publish, [creator, :create, unit, attrs, __MODULE__])
        {:ok, unit}
      end
    end)
  end

  defp insert_unit(creator, attrs) do
    repo().insert(Unit.create_changeset(creator, attrs))
  end

  defp insert_unit(creator, context, attrs) do
    repo().insert(Unit.create_changeset(creator, context, attrs))
  end

  # TODO: take the user who is performing the update
  @spec update(%Unit{}, attrs :: map) :: {:ok, Bonfire.Quantify.Unit.t()} | {:error, Changeset.t()}
  def update(%Unit{} = unit, attrs) do
    repo().update(Unit.update_changeset(unit, attrs))
  end

  def soft_delete(%Unit{} = unit) do
    repo().transact_with(fn ->
      with {:ok, unit} <- Bonfire.Common.Repo.Delete.soft_delete(unit) do
        # :ok <- publish(unit, :deleted) do
        {:ok, unit}
      end
    end)
  end

  def ap_publish_activity(activity_name, thing) do
    ValueFlows.Util.Federation.ap_publish_activity(activity_name, :unit, thing, 1, [
    ])
  end

  def ap_receive_activity(creator, activity, object) do
    ValueFlows.Util.Federation.ap_receive_activity(creator, activity, object, &create/2)
  end
end
