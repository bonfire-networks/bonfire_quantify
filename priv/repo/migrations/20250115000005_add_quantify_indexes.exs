defmodule Bonfire.Quantify.Repo.Migrations.AddQuantifyIndexes do
  @moduledoc false
use Ecto.Migration 
  use Needle.Migration.Indexable

  def up do
    Bonfire.Quantify.Migrations.add_unit_indexes()
    Bonfire.Quantify.Migrations.add_measure_indexes()
  end

  def down, do: nil
end
