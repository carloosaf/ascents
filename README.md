# Climb

## Local services

The local development stack uses Docker Compose for PostgreSQL and MinIO. Shared local settings live in `.env`, which is read by both Docker Compose and the Phoenix development/test configuration.

Review or edit local values in `.env` before starting services:

```sh
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=climb_dev
POSTGRES_TEST_DB=climb_test
MINIO_API_PORT=9000
MINIO_CONSOLE_PORT=9001
S3_ENDPOINT=http://localhost:9000
S3_BUCKET=climb-dev
```

Validate the compose file:

```sh
docker compose config
```

Start the local services:

```sh
docker compose up -d postgres minio
```

The Phoenix development and test database configuration reads `.env` first and then uses any real shell environment variables as overrides.

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Health baseline

Before starting feature work, verify the generated Phoenix baseline:

```sh
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix precommit
```

`mix precommit` is the final local gate for this project.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
