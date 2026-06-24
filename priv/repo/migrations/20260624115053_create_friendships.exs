defmodule Ascents.Repo.Migrations.CreateFriendships do
  use Ecto.Migration

  def change do
    create table(:friendships) do
      add :requester_id, references(:users, on_delete: :delete_all), null: false
      add :recipient_id, references(:users, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "pending"
      add :responded_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:friendships, [:requester_id, :status])
    create index(:friendships, [:recipient_id, :status])

    create unique_index(
             :friendships,
             ["LEAST(requester_id, recipient_id)", "GREATEST(requester_id, recipient_id)"],
             name: :friendships_user_pair_index
           )

    create constraint(:friendships, :friendships_distinct_users_check,
             check: "requester_id <> recipient_id"
           )

    create constraint(:friendships, :friendships_status_check,
             check: "status IN ('pending', 'accepted', 'declined')"
           )

    create constraint(:friendships, :friendships_response_check,
             check:
               "(status = 'pending' AND responded_at IS NULL) OR " <>
                 "(status IN ('accepted', 'declined') AND responded_at IS NOT NULL)"
           )
  end
end
