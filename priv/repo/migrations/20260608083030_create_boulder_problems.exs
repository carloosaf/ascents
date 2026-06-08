defmodule Ascents.Repo.Migrations.CreateBoulderProblems do
  use Ecto.Migration

  def change do
    create table(:boulder_problems) do
      add :gym_id, references(:gyms, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :grade, :string, null: false
      add :color, :string, null: false
      add :description, :string, size: 1000
      add :active, :boolean, null: false, default: true
      add :image_object_key, :string, size: 1024
      add :archived_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:boulder_problems, [:gym_id])
    create index(:boulder_problems, [:gym_id, :active])
    create index(:boulder_problems, [:gym_id, :grade])
  end
end
