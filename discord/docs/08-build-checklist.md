# 08 · Build Checklist

**[x]** = done in this repository (code, texts, tests). **[ ]** = still to do by the Owner on Discord or on the hosting machine. Nothing has been created on a real Discord server yet.

## A. Prepared in the repository

- [x] Server blueprint: 16 categories, 86 channels, permissions per channel ([01](01-server-blueprint.md))
- [x] Role hierarchy: 40 roles with colours, order and server-wide permissions ([02](02-role-hierarchy.md))
- [x] Permission matrix, calculated from the real overwrites ([03](03-permission-matrix.md))
- [x] Ready-to-post messages for every public info channel ([04](04-messages.md), `discord/messages/`)
- [x] Ticket forms for support, reports, appeals, 10 application types, registry and court
- [x] Ro-Nation Economy Bot: economy, daily report, verification, tickets, rosters, moderation helper
- [x] Server setup script (dry run by default, never deletes)
- [x] Message posting script (edits instead of duplicating)
- [x] Slash command registration script
- [x] Database schema with automatic creation on first start
- [x] Daily backups, audit log, alerts
- [x] 66 automated tests passing, 30-day offline simulation with balanced books ([09](09-qa-report.md))
- [x] Setup guide ([07](07-setup-guide.md))

## B. Discord account and server (Owner)

- [ ] Create the Discord server (or choose the existing one)
- [ ] Enable Community
- [ ] Safety settings: verification level Medium, media filter, 2FA for moderators
- [ ] Turn on 2FA on your own Discord account

## C. Bot application (Owner)

- [ ] Create the application in the Developer Portal
- [ ] Turn off "Public Bot", turn on "Server Members Intent"
- [ ] Copy Application ID and token into `discord/bot/.env` (never anywhere else)
- [ ] Invite the bot with the setup link (includes temporary Administrator)

## D. Hosting (Owner)

- [ ] Choose a machine that runs 24/7 (VPS recommended)
- [ ] Install Node.js 22.13+ and the code; `npm install`
- [ ] `npm test` shows 66 passing tests on that machine
- [ ] Set up a process manager (pm2 or systemd) so the bot restarts after crashes and reboots
- [ ] Plan where to copy `data/backups/` regularly

## E. Build the server (Owner)

- [ ] Drag the bot role to the top of the role list
- [ ] `npm run setup-server` (dry run) and read the plan
- [ ] `npm run setup-server -- --apply --sync-existing`
- [ ] Drag the bot role below "Economic Administrator"
- [ ] Remove Administrator and Manage Channels from the bot role
- [ ] Give yourself the Owner role
- [ ] Dry run again: everything "ok"
- [ ] `npm run deploy-commands`
- [ ] `npm start` (economic day 1 begins)
- [ ] `npm run post-messages -- --apply`

## F. Finishing touches (Owner)

- [ ] Community settings: rules channel #rules, updates channel #official-notices
- [ ] AutoMod rules with alerts to #moderation-log
- [ ] Server icon and bot avatar (Kagundi emblem or flag)
- [ ] Pin the welcome message; optionally pin the encyclopedia in #kagundi-lore
- [ ] Post the office-holder list in #government-information
- [ ] Default notifications: Only @mentions
- [ ] Optional: Onboarding (without giving Verified Member)

## G. People (Owner)

- [ ] Choose 1–3 Administrators, Moderators, Support Team, Economic Administrator(s)
- [ ] Appoint the Secretary-General and the four Secretaries (`/roster add`)
- [ ] Appoint department commands (Police, Gendarmerie, Armed Forces, Guard, EMS, Brandwehr) so they can recruit with `/roster`
- [ ] Brief staff: [05](05-bots-and-integrations.md) (commands) and [06](06-economy-design.md) (economy rules)

## H. Test before opening (Owner, with a second account)

- [ ] Unverified account sees only START HERE and cannot write
- [ ] Verification button works; account-age rule works; `/mod verify` works
- [ ] `/bank balance` reply is private; starting grant paid once
- [ ] Ticket opens privately, can be closed, reopened and deleted with a transcript
- [ ] A department leader can `/roster add` only their own department
- [ ] `/mod restrict` hides the server and leaves #appeals; `/mod unrestrict` restores roles
- [ ] First National Economic Report appears after midnight (Europe/Berlin)
- [ ] `/econ-admin tick-status` shows the day as completed and the ledger check OK
- [ ] Restart the bot once and check that nothing is posted twice

## I. After launch

- [ ] Review the economy numbers after two weeks (treasury balance, inflation, unemployment) and adjust policy if needed
- [ ] Check #bot-alerts daily in the first week
- [ ] Copy the backups off the machine weekly
