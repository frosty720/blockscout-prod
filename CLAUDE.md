# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Blockscout is a blockchain explorer built as an Elixir umbrella application (v11.0.0). It indexes blockchain data via JSON-RPC and serves it through REST and GraphQL APIs. Requires Elixir ~> 1.19, OTP 27, and PostgreSQL.

## Umbrella Apps

- **`apps/explorer`** — Core data layer. Ecto schemas, domain logic (`Explorer.Chain`), and a multi-repo PostgreSQL setup (main repo, replicas, feature-specific repos like Account, Arbitrum, Optimism, etc.). Migrations live in `priv/repo/migrations/` and chain-specific dirs like `priv/arbitrum/migrations/`.
- **`apps/block_scout_web`** — Phoenix web app. REST API (v1 Etherscan-compatible + v2), GraphQL (Absinthe), WebSocket channels.
- **`apps/indexer`** — Fetches blockchain data from JSON-RPC nodes. Runs fetchers under a supervision tree. Does NOT start in test mode.
- **`apps/ethereum_jsonrpc`** — JSON-RPC HTTP/WebSocket client for Ethereum-compatible nodes.
- **`apps/nft_media_handler`** — NFT image/metadata processing with S3 integration. Can run as a standalone microservice.
- **`apps/utils`** — Shared utilities, config helpers, custom Credo checks.

## Common Commands

```bash
# Dependencies & build
mix deps.get
mix compile

# Run all tests (use --no-start because indexer supervision tree should not start in tests)
mix test --no-start

# Run tests for a specific app
cd apps/explorer && mix test --no-start
cd apps/ethereum_jsonrpc && mix test --no-start --exclude no_nethermind

# Run a single test file or line
mix test --no-start apps/explorer/test/explorer/chain_test.exs
mix test --no-start apps/explorer/test/explorer/chain_test.exs:42

# Linting & static analysis
mix credo
mix dialyzer

# Database setup (requires DATABASE_URL or default postgres config)
mix ecto.create
mix ecto.migrate

# Docker (from docker/ directory)
make start   # Start all services
make stop    # Stop all services
```

## Key Environment Variables

- `DATABASE_URL` — PostgreSQL connection string
- `ETHEREUM_JSONRPC_HTTP_URL` / `ETHEREUM_JSONRPC_TRACE_URL` / `ETHEREUM_JSONRPC_WS_URL` — RPC endpoints
- `CHAIN_ID` — Blockchain chain ID
- `CHAIN_TYPE` — Chain variant (e.g., `arbitrum`, `optimism`, `zksync`, `filecoin`). Affects compile-time schema and runtime behavior.

## Database Architecture

Uses a multi-repo pattern. `Explorer.Repo` is the main read-write repo. Additional repos are loaded conditionally at runtime based on enabled features and chain type (configured in `config/config_helper.exs`). Each chain type can have its own migrations directory and Ecto repo.

## Configuration Philosophy

**Strongly prefer runtime configuration** over compile-time. Use `Utils.RuntimeEnvHelper` with pattern matching instead of `Utils.CompileTimeEnvHelper` with `if @chain_type == :x`. Compile-time config is only acceptable when modifying existing database schema structures. See `.github/CONTRIBUTING.md` for the full decision tree.

For new API endpoints: use `chain_scope` macro for chain-specific routes or `CheckFeature` plug for feature toggles.

## Naming Conventions

- Use full names: `transaction` not `tx`, `address_hash` not `address`, `block_number` not `block_num`.
- API v2 response fields: block numbers as integers with `_block_number` suffix, hashes as hex strings with `_hash` suffix, counts as `_count` suffix with plural entity name (e.g., `transactions_count`), indexes as numbers.

## PR and Commit Conventions

- PR titles follow Conventional Commits: `feat:`, `fix:`, `chore:`, `doc:`, `perf:`, `refactor:`.
- Bug fixes should ideally be two commits: (1) regression test showing the failure, (2) the fix.
- Schema changes that require re-indexing must note `**NOTE**: A database reset and re-index is required` in the PR.
- Keep `.dialyzer_ignore.exs` minimal; every entry needs justification.

## Code Style

- Line length: 120 characters (`.formatter.exs`)
- Run `mix format` before committing
- Credo strict mode is enabled with custom checks in `apps/utils/lib/credo/`

## Testing Notes

- Tests require a running PostgreSQL instance (default: `explorer_test` database, user `postgres`, password `postgres`)
- Uses Ecto sandbox for test isolation (`Explorer.DataCase`)
- Factory pattern via `ex_machina` in test support files
- CI tests against 16+ chain type matrix configurations
- The `--exclude no_nethermind` flag skips tests requiring a live Nethermind node
