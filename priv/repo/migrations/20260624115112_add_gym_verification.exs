defmodule Ascents.Repo.Migrations.AddGymVerification do
  use Ecto.Migration

  def change do
    alter table(:gyms) do
      add :verification_status, :string, null: false, default: "community"
      add :verification_requested_at, :utc_datetime

      add :verification_requested_by_user_id,
          references(:users, on_delete: :restrict)

      add :verification_request_note, :string, size: 1000
      add :verified_by_user_id, references(:users, on_delete: :restrict)
      add :verification_note, :string, size: 1000
    end

    # `verified_at` was previously an unused placeholder. Clear any legacy
    # values so no pre-existing row can imply official status without the new
    # request and platform-review audit trail.
    execute(
      "UPDATE gyms SET verified_at = NULL WHERE verified_at IS NOT NULL",
      "SELECT 1"
    )

    create index(:gyms, [:verification_status])
    create index(:gyms, [:verification_requested_by_user_id])
    create index(:gyms, [:verified_by_user_id])

    create constraint(:gyms, :gyms_verification_status_check,
             check: "verification_status IN ('community', 'pending', 'verified')"
           )

    create constraint(:gyms, :gyms_verification_metadata_check,
             check: """
             (
               verification_status = 'community'
               AND verification_requested_at IS NULL
               AND verification_requested_by_user_id IS NULL
               AND verification_request_note IS NULL
               AND verified_at IS NULL
               AND verified_by_user_id IS NULL
               AND verification_note IS NULL
             )
             OR
             (
               verification_status = 'pending'
               AND verification_requested_at IS NOT NULL
               AND verification_requested_by_user_id IS NOT NULL
               AND verification_request_note IS NOT NULL
               AND verified_at IS NULL
               AND verified_by_user_id IS NULL
               AND verification_note IS NULL
             )
             OR
             (
               verification_status = 'verified'
               AND verification_requested_at IS NOT NULL
               AND verification_requested_by_user_id IS NOT NULL
               AND verification_request_note IS NOT NULL
               AND verified_at IS NOT NULL
               AND verified_by_user_id IS NOT NULL
             )
             """
           )
  end
end
