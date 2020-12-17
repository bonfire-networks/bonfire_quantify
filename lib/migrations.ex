defmodule Bonfire.Quantify.Migrations do
  use Ecto.Migration
  import Pointers.Migration

  alias Measurement

  @user Bonfire.Common.Config.get_ext(:bonfire_quantify, :user_schema)

  def unit_table(), do: Bonfire.Quantify.Unit.__schema__(:source)
  def measure_table(), do: Bonfire.Quantify.Measure.__schema__(:source)
  # def users_table(), do: @user.__schema__(:source)

  def change do
    create_pointable_table(Bonfire.Quantify.Unit) do
      add(:label, :string)
      add(:symbol, :string)

      add(:context_id, weak_pointer(), null: true)
      add(:creator_id, weak_pointer(@user), null: true)

      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:disabled_at, :timestamptz)

      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end
  end

  def change_measure do
    create_pointable_table(Bonfire.Quantify.Measure) do
      add(:has_numerical_value, :float)

      add(:unit_id, strong_pointer(Bonfire.Quantify.Unit), null: false)
      add(:creator_id, weak_pointer(@user), null: true)

      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:disabled_at, :timestamptz)

      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end
  end
end
