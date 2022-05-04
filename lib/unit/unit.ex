defmodule Bonfire.Quantify.Unit do
  use Pointers.Pointable,
    otp_app: :bonfire_quantify,
    source: "measurement_unit",
    table_id: "3N1TF0RMEASVRES0RQVANT1T1E"

  import Bonfire.Common.Repo.Utils, only: [change_public: 1, change_disabled: 1]

  alias Ecto.Changeset
  alias Bonfire.Common.Utils
  alias Pointers.Pointer
  @user Bonfire.Common.Config.get!(:user_schema)

  # alias Bonfire.Quantify.Unit

  @type t :: %__MODULE__{}

  pointable_schema do
    field(:label, :string)
    field(:symbol, :string)

    field(:is_public, :boolean, virtual: true)
    field(:published_at, :utc_datetime_usec)
    field(:is_disabled, :boolean, virtual: true, default: false)
    field(:disabled_at, :utc_datetime_usec)
    field(:deleted_at, :utc_datetime_usec)

    belongs_to(:creator, @user)
    belongs_to(:context, Pointer)

    timestamps(inserted_at: false)
  end

  @required ~w(label symbol)a
  @cast @required ++ ~w(is_disabled is_public)a

  def create_changeset(
        creator,
        attrs
      ) do
    %Bonfire.Quantify.Unit{}
    |> Changeset.cast(attrs, @cast)
    |> Changeset.validate_required(@required)
    |> Changeset.change(
      creator_id: Utils.e(creator, :id, nil),
      is_public: true
    )
    |> common_changeset()
  end

  def create_changeset(
        creator,
        %{id: _} = context,
        attrs
      ) do
    %Bonfire.Quantify.Unit{}
    |> Changeset.cast(attrs, @cast)
    |> Changeset.validate_required(@required)
    |> Changeset.change(
      creator_id: Utils.e(creator, :id, nil),
      context_id: context.id,
      is_public: true
    )
    |> common_changeset()
  end

  def update_changeset(%Bonfire.Quantify.Unit{} = unit, attrs) do
    unit
    |> Changeset.cast(attrs, @cast)
    |> common_changeset()
  end

  defp common_changeset(changeset) do
    changeset
    |> change_public()
    |> change_disabled()
  end
end
