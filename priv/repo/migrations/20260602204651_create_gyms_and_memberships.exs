defmodule Ascents.Repo.Migrations.CreateGymsAndMemberships do
  use Ecto.Migration

  def change do
    create table(:gyms) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :string, size: 500
      add :location, :string, size: 160
      add :grade_scale, :string, null: false, default: "v_scale"
      add :creator_id, references(:users, on_delete: :restrict), null: false
      add :verified_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:gyms, [:slug])
    create index(:gyms, [:creator_id])

    create constraint(:gyms, :gyms_grade_scale_check,
             check: "grade_scale IN ('v_scale', 'french')"
           )

    create table(:gym_memberships) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :gym_id, references(:gyms, on_delete: :delete_all), null: false
      add :role, :string, null: false, default: "member"
      add :joined_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:gym_memberships, [:user_id, :gym_id])
    create index(:gym_memberships, [:gym_id])
    create index(:gym_memberships, [:user_id])
    create index(:gym_memberships, [:gym_id, :role])

    create constraint(:gym_memberships, :gym_memberships_role_check,
             check: "role IN ('owner', 'admin', 'mod', 'member')"
           )
  end
end
