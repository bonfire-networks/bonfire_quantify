defmodule Bonfire.PublisherThesis.Repo.Migrations.ImportMe do
  use Ecto.Migration

  import Bonfire.PublisherThesis.Migration
  # accounts & users

  def change, do: migrate_thesis

end
