defmodule Ascents.Repo.Migrations.CreateAscents do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      modify :body, :text, null: true, from: {:text, null: false}
      add :post_type, :string, null: false, default: "normal"
      add :boulder_problem_id, references(:boulder_problems, on_delete: :nilify_all)
    end

    create index(:posts, [:post_type])
    create index(:posts, [:boulder_problem_id])

    create constraint(:posts, :posts_post_type_check, check: "post_type IN ('normal', 'ascent')")

    create table(:ascents) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :gym_id, references(:gyms, on_delete: :delete_all), null: false
      add :boulder_problem_id, references(:boulder_problems, on_delete: :restrict), null: false
      add :post_id, references(:posts, on_delete: :delete_all), null: false
      add :climbed_at, :utc_datetime, null: false
      add :grade_snapshot, :string, null: false
      add :grade_scale_snapshot, :string, null: false
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:ascents, [:post_id])
    create index(:ascents, [:user_id, :climbed_at])
    create index(:ascents, [:gym_id, :climbed_at])
    create index(:ascents, [:boulder_problem_id])
    create index(:ascents, [:deleted_at])
  end
end
