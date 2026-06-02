# Ascents

Ascents is a free-time project exploring what a climbing-focused social media
MVP could look like.

The product idea is simple: give climbing gyms and their communities a place to
exist online, with member profiles, gym communities, posts, boulder problems,
ascent logging, media, comments, moderation, and personal stats growing in that
order. This repository is not a finished social network. It is the working MVP
codebase where that idea is being tested.

## Why this exists

This is a personal project, built outside work time, with two goals:

1. Build a credible MVP for a social app around climbing communities.
2. Use the project as a serious test bed for agentic AI workflows and
   capabilities.

I am not approaching this as "vibe coding". The point is to understand where AI
tools are actually useful in software work: planning, implementation, review,
testing, design iteration, debugging, documentation, and the handoff between
human judgment and machine-generated output. The repository is public partly so
that process, tradeoff, and code quality can be inspected.

## Product direction

Ascents is planned around gym-centered climbing communities:

- climber accounts and public profiles
- gym creation and membership
- gym feeds for normal posts and ascent posts
- boulder problem management
- ascent history and personal stats
- image upload support through object storage
- basic gym-level moderation

The current direction and task breakdown live in `.plans/`, especially
`.plans/ascents-social-plan.html`.

## Current state

Implemented or started:

- Phoenix 1.8 application baseline
- generated authentication
- public profile fields
- custom product components and visual direction
- local PostgreSQL and MinIO services
- gym and gym membership context
- project health gate through `mix precommit`

Planned next areas include gym LiveViews, boulder problem management, feed
features, ascent posting, media handling, stats, and moderation.

## Tech stack

- Elixir and Phoenix
- Phoenix LiveView
- Ecto and PostgreSQL
- Tailwind CSS
- MinIO-compatible object storage for local media work
- Req for HTTP requests

## Local development

Local services are defined with Docker Compose. Shared local settings live in
`.env`, which is read by both Docker Compose and the Phoenix development/test
configuration.

Review or edit local values in `.env` before starting services:

```sh
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=ascents_dev
POSTGRES_TEST_DB=ascents_test
MINIO_API_PORT=9000
MINIO_CONSOLE_PORT=9001
S3_ENDPOINT=http://localhost:9000
S3_BUCKET=ascents-dev
```

Validate the compose file:

```sh
docker compose config
```

Start the local services:

```sh
docker compose up -d postgres minio
```

Install dependencies, prepare the database, and build assets:

```sh
mix setup
```

Start the Phoenix server:

```sh
mix phx.server
```

Or run it inside IEx:

```sh
iex -S mix phx.server
```

Then visit [localhost:4000](http://localhost:4000).

## Quality gate

Before considering changes done, run:

```sh
mix precommit
```

The alias compiles with warnings as errors, checks unused dependencies, formats
the codebase, and runs the test suite.

For focused checks during development:

```sh
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

## Planning artifacts

The `.plans/` directory contains product and implementation planning documents.
They are intentionally kept in the repository because the planning process is
part of the experiment:

- `.plans/ascents-social-plan.html` describes the product scope, MVP
  requirements, domain model, risks, and implementation sequence.
- `.plans/tasks-1-2-implementation-plan.html` covers the local services and
  health baseline.
- `.plans/task-3-design-system-plan.html` covers the visual direction and
  component system.
- `.plans/task-4-profile-extension-plan.html` covers public profile work.
- `.plans/task-5-gym-context-plan.html` covers gyms and memberships.

## Contributing

This is primarily a personal experiment, but the code is public and the license
is permissive. Issues, ideas, and pull requests are welcome if they fit the MVP
direction and keep the project small enough to reason about.

Useful contributions include bug reports, test coverage, UI polish, product
questions, review of the domain model, and concrete improvements to the
Phoenix/LiveView implementation.

## License

Ascents is released under the MIT License. See `LICENSE` for details.
