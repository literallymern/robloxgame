---
channel: economy_guide
---
# Economy guide

Kagundi has a **persistent economy**. Every Dinar exists on an account, every payment is recorded, and money can only enter or leave through defined channels (wages from the treasury, exports, loans, central bank decisions). The bot runs it; you use it with slash commands in #bank-terminal.

## Your money
- `/bank balance` your bank account, cash, card and credit score (private)
- `/bank pay` pay a person or business · `/bank withdraw` / `/bank deposit` move cash
- `/bank transactions` your history · `/bank credit` your credit score and conditions

## The economic day
The economic day runs from **00:00 to 24:00 Berlin time**. At midnight the bot closes the day exactly once: wages, rent, loan payments, insurance premiums, licence fees and taxes are booked, prices for the next day are set, and the **National Economic Report** appears in #national-economic-report. If the bot was offline, it processes missed days in order when it is back. Nothing is paid twice.

## Taxes and fees (current defaults, the government can change them)
- Income tax **10%** (withheld from wages) · Turnover tax **5%** on business income
- Distribution tax **10%** on profit withdrawals · Property tax **1.5%** per year · Transfer tax **2%** on property sales
- Business registration **1,000 KGD** · daily licence fees per industry
- Export duties and import tariffs per commodity: see `/economy markets`
- Minimum private wage **150 KGD/day**, maximum **2,500 KGD/day**

## Credit
Credit scores range from **300 to 850** (start: 600). On-time payments raise it; missed payments, overdue fines, evictions and defaults lower it.
- **800–850** Excellent: 5% per year, loans up to 50,000 KGD
- **700–799** Good: 7%, up to 25,000 KGD
- **600–699** Average: 10%, up to 10,000 KGD
- **500–599** Poor: 14%, up to 2,000 KGD
- **300–499** Very Poor: 18%, no new loans
Rates move with the central bank policy rate (default 6%).
