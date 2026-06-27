defmodule Ascents.Gyms.Gym do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ascents.Accounts.User
  alias Ascents.Ascents.Ascent
  alias Ascents.Feed.Post
  alias Ascents.Gyms.GymMembership
  alias Ascents.Routes.BoulderProblem
  alias Ascents.Sessions.Session

  @grade_scales ~w(v_scale french)
  @verification_statuses ~w(community pending verified)

  schema "gyms" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :location, :string
    field :image_object_key, :string
    field :grade_scale, :string, default: "v_scale"
    field :verification_status, :string, default: "community"
    field :verification_requested_at, :utc_datetime
    field :verification_request_note, :string
    field :verified_at, :utc_datetime
    field :verification_note, :string

    belongs_to :verification_requested_by_user, User
    belongs_to :verified_by_user, User

    has_many :memberships, GymMembership
    has_many :boulder_problems, BoulderProblem
    has_many :posts, Post
    has_many :ascents, Ascent
    has_many :sessions, Session

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for gym community metadata.
  """
  def changeset(gym, attrs) do
    gym
    |> cast(attrs, [:name, :slug, :description, :location, :image_object_key, :grade_scale])
    |> update_change(:name, &trim_string/1)
    |> update_change(:description, &trim_string/1)
    |> update_change(:location, &trim_string/1)
    |> update_change(:image_object_key, &trim_string/1)
    |> update_change(:slug, &normalize_slug/1)
    |> validate_required([:name, :slug, :grade_scale])
    |> validate_length(:name, min: 2, max: 120)
    |> validate_length(:slug, min: 2, max: 120)
    |> validate_format(:slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/,
      message: "must use lowercase letters, numbers, and hyphens"
    )
    |> validate_length(:description, max: 500)
    |> validate_length(:location, max: 160)
    |> validate_length(:image_object_key, max: 1024)
    |> validate_inclusion(:grade_scale, @grade_scales)
    |> unique_constraint(:slug)
    |> check_constraint(:grade_scale, name: :gyms_grade_scale_check)
  end

  @doc false
  def verification_request_changeset(gym, %User{} = user, note, now) do
    gym
    |> cast(%{"verification_request_note" => note}, [:verification_request_note])
    |> update_change(:verification_request_note, &trim_string/1)
    |> put_change(:verification_status, "pending")
    |> put_change(:verification_requested_at, now)
    |> put_change(:verification_requested_by_user_id, user.id)
    |> put_change(:verified_at, nil)
    |> put_change(:verified_by_user_id, nil)
    |> put_change(:verification_note, nil)
    |> validate_required([
      :verification_status,
      :verification_requested_at,
      :verification_requested_by_user_id,
      :verification_request_note
    ])
    |> validate_length(:verification_request_note, min: 20, max: 1000)
    |> verification_constraints()
  end

  @doc false
  def verification_approval_changeset(gym, %User{} = user, note, now) do
    gym
    |> cast(%{"verification_note" => note}, [:verification_note])
    |> update_change(:verification_note, &blank_to_nil/1)
    |> put_change(:verification_status, "verified")
    |> put_change(:verified_at, now)
    |> put_change(:verified_by_user_id, user.id)
    |> validate_length(:verification_note, max: 1000)
    |> verification_constraints()
  end

  @doc false
  def verification_revoke_changeset(gym) do
    gym
    |> change(%{
      verification_status: "community",
      verification_requested_at: nil,
      verification_requested_by_user_id: nil,
      verification_request_note: nil,
      verified_at: nil,
      verified_by_user_id: nil,
      verification_note: nil
    })
    |> verification_constraints()
  end

  def verification_statuses, do: @verification_statuses

  defp verification_constraints(changeset) do
    changeset
    |> validate_inclusion(:verification_status, @verification_statuses)
    |> check_constraint(:verification_status, name: :gyms_verification_status_check)
    |> check_constraint(:verification_status, name: :gyms_verification_metadata_check)
  end

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value

  defp trim_string(value) when is_binary(value), do: String.trim(value)
  defp trim_string(value), do: value

  defp normalize_slug(slug) when is_binary(slug) do
    slug
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_slug(slug), do: slug
end
