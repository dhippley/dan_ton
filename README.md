# DanTon

A Phoenix LiveView application following the AGENTS rules.

## Prerequisites

- Elixir 1.15+
- Docker and Docker Compose (for databases)

## Getting Started

### 1. Start the database

```bash
docker compose up -d
```

This will start PostgreSQL on `localhost:5432` with:
- Username: `postgres`
- Password: `postgres`
- Database: `dan_ton_dev`

### 2. Install dependencies

```bash
mix deps.get
```

### 3. Create and migrate database

```bash
mix ecto.create
mix ecto.migrate
```

### 4. Install frontend dependencies

```bash
mix assets.setup
```

### 5. Start the Phoenix server

```bash
mix phx.server
```

Now visit [`localhost:4000`](http://localhost:4000) from your browser.

## Development

### Running the precommit checks

```bash
mix precommit
```

This runs:
- `mix deps.get` - Ensures dependencies are up to date
- `mix format` - Formats code
- `mix credo --strict` - Lints code
- `mix sobelow --config` - Security analysis

### Stopping the database

```bash
docker compose down
```

To remove volumes (deletes all data):

```bash
docker compose down -v
```

## Project Structure

- `lib/dan_ton` - Core application logic
- `lib/dan_ton_web` - Web layer (LiveView, controllers, components)
- `priv/repo/migrations` - Database migrations
- `test/` - Tests

## Additional Documentation

See `AGENTS.mdc` for the complete set of development rules and guidelines.