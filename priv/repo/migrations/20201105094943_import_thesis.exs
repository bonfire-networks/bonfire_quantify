defmodule Bonfire.Quantify.Repo.Migrations.ImportMe do
  use Ecto.Migration

  import Bonfire.Quantify.Migration
  # accounts & users

  def change, do: migrate_thesis

end
