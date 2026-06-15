# Task 17 MVP Acceptance Checklist

Task 17 verifies the implemented MVP as a coherent product flow rather than a single feature.

## Demo Data

Run the seed script after PostgreSQL and MinIO are running:

```sh
mix run priv/repo/seeds.exs
```

Primary demo login:

```text
Email: vela@ascents.local
Password: climbdemo123!
```

The seed script is idempotent for database records. It creates or updates demo users, gyms, memberships, boulder problems, normal posts, comments, and ascent posts. Demo image objects are uploaded through the existing media boundary when seeded records do not already have an image object key.

## Manual Flow

1. Start services with `docker compose up -d postgres minio minio-init`.
2. Prepare the database with `mix ecto.setup` or refresh it with `mix ecto.reset`.
3. Start Phoenix with `mix phx.server`.
4. Visit `http://localhost:4000` while anonymous and confirm the marketing/home page loads.
5. Register a new user through `/users/register` and confirm the registration flow sends a login instruction in the local mailbox.
6. Log in with `vela@ascents.local` and `climbdemo123!`.
7. Confirm authenticated `/` redirects to `/feed`.
8. Confirm `/feed` shows posts from joined gyms, including ascent posts with route metadata.
9. Visit `/gyms/bloc-district` and confirm the gym header, route list, feed, join/leave controls, comments, and images render.
10. Create a new gym through `/gyms/new` and confirm the creator becomes owner.
11. Add a route from the new gym's route admin UI and confirm it appears on the gym page.
12. Join the gym as a member account and create an ascent post with an active boulder problem.
13. Visit `/users/stats` and confirm totals, grade distribution, gym distribution, and recent timeline are populated.
14. Delete one of the current user's posts or comments and confirm it disappears from visible feeds.
15. Review `/dev/components` in development and confirm the core feed, route, stat, empty, and media treatments still render.

## Automated Verification

Run the project quality gate after changes:

```sh
mix precommit
```

This intentionally relies on the existing focused context, controller, and LiveView tests rather than adding a broad high-level acceptance test.
