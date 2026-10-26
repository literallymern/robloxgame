# Ro-Nation Discord · Democratic Republic of Kagundi

Everything for the Ro-Nation Discord server: the server blueprint, roles and permissions, all ready-to-post texts, and the **Ro-Nation Economy Bot**, which runs Kagundi's economic simulation and posts the daily National Economic Report.

This folder is separate from the Roblox game (Rojo project in the repository root) and does not change it.

> **Status:** finished and tested offline. Nothing has been set up on Discord yet. Start with the [setup guide](docs/07-setup-guide.md).

## Folder layout

```
discord/
├── docs/        Documentation 01–10 (start with 07-setup-guide.md)
├── messages/    Ready-to-post texts, one file per channel
├── assets/      Kagundi flag and emblem
└── bot/         The Ro-Nation Economy Bot (Node.js)
    ├── src/         Bot, economy simulation, blueprint
    ├── scripts/     setup-server, deploy-commands, post-messages, simulate, generate-docs
    ├── test/        Automated tests
    └── .env.example Settings template (copy to .env, never commit .env)
```

## Documentation

1. [Server blueprint](docs/01-server-blueprint.md)
2. [Role hierarchy](docs/02-role-hierarchy.md)
3. [Permission matrix](docs/03-permission-matrix.md)
4. [Ready-to-use messages](docs/04-messages.md)
5. [Bots and integrations](docs/05-bots-and-integrations.md)
6. [Economic simulation design](docs/06-economy-design.md)
7. [Setup guide](docs/07-setup-guide.md)
8. [Build checklist](docs/08-build-checklist.md)
9. [QA report](docs/09-qa-report.md)
10. [Final summary and assumptions](docs/10-summary.md)

Appendix: [slash command reference](docs/appendix-command-reference.md)

## Quick start

Requires Node.js 22.13 or newer.

```
cd discord/bot
npm install
npm test                      # 67 tests, no Discord needed
npm run simulate -- 30        # 30 simulated days, prints the National Economic Report
```

Then follow [docs/07-setup-guide.md](docs/07-setup-guide.md): fill in `.env`, `npm run setup-server`, `npm run deploy-commands`, `npm start`, `npm run post-messages -- --apply`.

## Commands for maintainers

| Command | What it does |
|---|---|
| `npm start` | Runs the bot |
| `npm test` | Runs all tests |
| `npm run setup-server` | Compares the server with the blueprint (dry run); `-- --apply` builds it |
| `npm run deploy-commands` | Registers the slash commands on the server |
| `npm run post-messages` | Shows (dry run) or posts (`-- --apply`) the texts and button panels |
| `npm run simulate -- <days>` | Offline economy simulation |
| `npm run generate-docs` | Rebuilds docs 01–03 and the command reference after blueprint changes |

## Security

- The bot token belongs only in `discord/bot/.env`. Never commit it, never post it in Discord.
- `data/` (database, backups, server IDs) is not committed.
- Fictional government roles never receive Discord permissions; see the [permission matrix](docs/03-permission-matrix.md).
