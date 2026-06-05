defmodule Ascents.Gyms.Gym do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ascents.Gyms.GymMembership

  @grade_scales ~w(v_scale french)

  schema "gyms" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :location, :string
    field :grade_scale, :string, default: "v_scale"
    field :verified_at, :utc_datetime

    has_many :memberships, GymMembership

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for gym community metadata.
  """
  def changeset(gym, attrs) do
    gym
    |> cast(attrs, [:name, :slug, :description, :location, :grade_scale])
    |> update_change(:name, &trim_string/1)
    |> update_change(:description, &trim_string/1)
    |> update_change(:location, &trim_string/1)
    |> update_change(:slug, &normalize_slug/1)
    |> validate_required([:name, :slug, :grade_scale])
    |> validate_length(:name, min: 2, max: 120)
    |> validate_length(:slug, min: 2, max: 120)
    |> validate_format(:slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/,
      message: "must use lowercase letters, numbers, and hyphens"
    )
    |> validate_length(:description, max: 500)
    |> validate_length(:location, max: 160)
    |> validate_inclusion(:grade_scale, @grade_scales)
    |> unique_constraint(:slug)
    |> check_constraint(:grade_scale, name: :gyms_grade_scale_check)
  end

  defp trim_string(value) when is_binary(value), do: String.trim(value)
  defp trim_string(value), do: value

  defp normalize_slug(slug) when is_binary(slug) do
    slug
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_slug(slug), do: slug
end
