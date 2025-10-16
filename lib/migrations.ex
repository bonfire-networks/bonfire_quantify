defmodule Bonfire.Quantify.Migrations do
  @moduledoc false
  use Ecto.Migration
  import Needle.Migration
  use Needle.Migration.Indexable

  alias Measurement

  @user Application.compile_env!(:bonfire, :user_schema)
  @unit_table Bonfire.Quantify.Unit.__schema__(:source)
  @measure_table Bonfire.Quantify.Measure.__schema__(:source)

  def change do
    create_pointable_table(Bonfire.Quantify.Unit) do
      add(:label, :string)
      add(:symbol, :string)

      add_pointer(:context_id, :weak, Needle.Pointer, null: true)
      add_pointer(:creator_id, :weak, Needle.Pointer, null: true)

      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:disabled_at, :timestamptz)

      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    add_unit_indexes()
  end

  def add_unit_indexes do
    create_index_for_pointer(@unit_table, :context_id)
    create_index_for_pointer(@unit_table, :creator_id)
  end

  def change_measure do
    create_pointable_table(Bonfire.Quantify.Measure) do
      add(:has_numerical_value, :float)

      add_pointer(:unit_id, :strong, Bonfire.Quantify.Unit, null: false)
      add_pointer(:creator_id, :weak, Needle.Pointer, null: true)

      add(:published_at, :timestamptz)
      add(:deleted_at, :timestamptz)
      add(:disabled_at, :timestamptz)

      timestamps(inserted_at: false, type: :utc_datetime_usec)
    end

    add_measure_indexes()
  end

  def add_measure_indexes do
    create_index_for_pointer(@measure_table, :unit_id)
    create_index_for_pointer(@measure_table, :creator_id)
  end
end
