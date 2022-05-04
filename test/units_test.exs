# # SPDX-License-Identifier: AGPL-3.0-only
defmodule Bonfire.Quantify.UnitsTest do
  use Bonfire.Quantify.ConnCase, async: true

  import Bonfire.Quantify.Test.Faking

  # import CommonsPub.Utils.Trendy
  import Bonfire.Common.Simulation
  # import CommonsPub.Utils.Simulate
  # import CommonsPub.Web.Test.Orderings
  # import CommonsPub.Web.Test.Automaton

  # import Grumble
  # import Zest


  import Bonfire.Quantify.Simulate
  alias Bonfire.Quantify.Unit
  alias Bonfire.Quantify.Units

  describe "one" do
    test "returns an item if it exists" do
      user = fake_user!(%{is_instance_admin: true})
      context = fake_user!()
      unit = fake_unit!(user, context)

      assert {:ok, fetched} = Units.one(id: unit.id)
      assert_unit(unit, fetched)
      assert {:ok, fetched} = Units.one(user: user)
      assert_unit(unit, fetched)
      assert {:ok, fetched} = Units.one(context_id: context.id)
      assert_unit(unit, fetched)
    end

    test "returns NotFound if item is missing" do
      assert {:error, :not_found} = Units.one(id: ulid())
    end

    test "returns NotFound if item is deleted" do
      unit = fake_user!() |> fake_unit!()
      assert {:ok, unit} = Units.soft_delete(unit)
      assert {:error, :not_found} = Units.one([:default, id: unit.id])
    end
  end

  describe "create without context" do
    test "creates a new unit" do
      user = fake_user!()
      assert {:ok, unit = %Unit{}} = Units.create(user, unit())
      assert unit.creator_id == user.id
    end
  end

  describe "create with context" do
    test "creates a new unit" do
      user = fake_user!()
      context = fake_user!()

      assert {:ok, unit = %Unit{}} = Units.create(user, context, unit())
      assert unit.creator_id == user.id
      assert unit.context_id == context.id
    end

    test "fails with invalid attributes" do
      assert {:error, %Ecto.Changeset{}} = Units.create(fake_user!(), %{})
    end
  end

  describe "update" do
    test "updates a a unit" do
      user = fake_user!()
      context = fake_user!()
      unit = fake_unit!(user, context, %{label: "Bottle Caps", symbol: "C"})
      assert {:ok, updated} = Units.update(unit, %{label: "Rad", symbol: "rad"})
      assert unit != updated
    end
  end

  describe "soft_delete" do
    test "deletes an existing unit" do
      unit = fake_user!() |> fake_unit!()
      refute unit.deleted_at
      assert {:ok, deleted} = Units.soft_delete(unit)
      assert deleted.deleted_at
    end
  end

  # describe "units" do

  #   test "works for a guest" do
  #     users = some_fake_users!(3)
  #     communities = some_fake_communities!(3, users) # 9
  #     units = some_fake_collections!(1, users, communities) # 27
  #     root_page_test %{
  #       query: units_query(),
  #       connection: json_conn(),
  #       return_key: :units,
  #       default_limit: 10,
  #       total_count: 27,
  #       data: order_follower_count(units),
  #       assert_fn: &assert_unit/2,
  #       cursor_fn: &[&1.id],
  #       after: :collections_after,
  #       before: :collections_before,
  #       limit: :collections_limit,
  #     }
  #   end

  # end
end
