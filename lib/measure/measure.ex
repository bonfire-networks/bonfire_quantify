# SPDX-License-Identifier: AGPL-3.0-only
defmodule Bonfire.Quantify.Measure do
  use Pointers.Pointable,
    otp_app: :commons_pub,
    source: "measurement_measure",
    table_id: "4EASVRES0RQVANT1T1ES0FVN1T"

  import Bonfire.Repo.Common, only: [change_public: 1, change_disabled: 1]

  alias Ecto.Changeset
  @user Bonfire.Common.Config.get!(:user_schema)
  alias Bonfire.Common.Utils
  alias Bonfire.Quantify.Unit

  @type t :: %__MODULE__{}

  pointable_schema do
    field(:has_numerical_value, :float)

    field(:is_public, :boolean, virtual: true)
    field(:published_at, :utc_datetime_usec)
    field(:is_disabled, :boolean, virtual: true, default: false)
    field(:disabled_at, :utc_datetime_usec)
    field(:deleted_at, :utc_datetime_usec)

    belongs_to(:unit, Unit)
    belongs_to(:creator, @user)

    timestamps(inserted_at: false)
  end

  @required ~w(has_numerical_value)a
  @cast @required ++ ~w(unit_id)a

  @doc "Copy the attributes of a measure required to create a new one."
  def copy(measure) do
    Bonfire.Common.Utils.maybe(measure, &Map.take(&1, [:has_numerical_value, :unit_id, :creator_id]))
  end

  def validate_changeset(
        %__MODULE__{} = measure \\ %__MODULE__{},
        attrs
      ) do
    measure
    |> Changeset.cast(attrs, @cast)
    |> Changeset.validate_required(@required)
    |> common_changeset()
  end

  def create_changeset(
        creator,
        %Unit{} = unit,
        attrs
      ) do
    validate_changeset(attrs)
    |> Changeset.change(
      creator_id: Utils.e(creator, :id, nil),
      unit_id: unit.id,
      is_public: true
    )
  end

  def update_changeset(%__MODULE__{} = measure, attrs) do
    measure
    |> Changeset.cast(attrs, @cast)
    |> common_changeset()
  end

  defp common_changeset(changeset) do
    changeset
    |> change_public()
    |> change_disabled()
  end
end
