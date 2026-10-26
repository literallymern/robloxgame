# 06 · Economic Simulation Design

The economy of the Democratic Republic of Kagundi is a persistent simulation run by the Ro-Nation Economy Bot. Every number below is a **gameplay parameter**, not a real-world statistic. All parameters live in [`bot/src/economy/constants.js`](../bot/src/economy/constants.js) and [`event-catalog.js`](../bot/src/economy/event-catalog.js); policy parameters can be changed in-game within fixed limits.

## 1. Principles

1. **Nothing is invented for the report.** The daily report is built only from what is stored in the database. Estimates (GDP, unemployment) are labelled "est.".
2. **Double-entry bookkeeping.** Money only moves between accounts. The sum of all balances is always exactly zero (the Central Bank, loan and card accounts and the rest of the world carry the negative side). The daily tick checks this and rolls the whole day back if it ever fails.
3. **Defined money sources.** New money enters only through the starting grant, loans, Central Bank financing (Owner only), admin corrections (audited) and the launch funding. Everything else is a transfer.
4. **Exactly once.** Every scheduled payment has an idempotency key, every economic day is processed once, and claims, invoices and grants can be paid only once.
5. **Bounded randomness.** Prices, exchange rate and events move within hard limits so players can plan.
6. **Casual-friendly.** One shift per day is enough to take part. Missing a day costs a shift's pay, not your house. Days processed late after bot downtime never cause penalties.
7. **Privacy.** Personal finances are only shown privately to their owner (and to staff through audited inspection).

## 2. Currency and accounts

- **Currency:** Kagundi Dinar (KGD), stored in minor units (1 KGD = 100). No floating-point money.
- **Account types:** personal bank, personal cash, business, loan, credit card, National Treasury, AVK, Central Bank, rest of world.
- **Money stock** = personal bank + cash + business + treasury + AVK balances.

| Money enters through | Money leaves through |
|---|---|
| Starting grant (2,500 KGD, once, Discord account at least 14 days old) | Loan and card repayments (principal) |
| Loan and card payouts | Interest and late fees (to the Central Bank) |
| Launch funds: treasury 1,500,000 KGD, AVK 200,000 KGD | Production costs and imports (to the rest of the world) |
| Export sales (from the rest of the world) | Admin corrections downwards (audited) |
| Central Bank financing of the treasury (Owner only, audited) | |
| Admin corrections upwards (audited, max 10,000 KGD per action unless Owner) | |

## 3. The economic day

An economic day runs from **00:00 to 24:00 Europe/Berlin**. Day 1 is the date the bot first starts. Right after midnight the bot processes the day that just ended, in one database transaction, in this order:

1. Expire old invoices; collect overdue fines
2. Production at producing businesses; daily licence fees
3. Wages (and income tax), rent, property tax, AVK premiums, loan and card payments
4. Prices for the next day: commodities, exchange rate, consumer prices
5. Credit scores
6. Random economic events (they start the next day)
7. Snapshot of all indicators and the National Economic Report
8. Integrity check of the books
9. Mark the day as completed

If any step fails, nothing of that day is saved; the bot retries with growing pauses (1 → 30 minutes) and posts an alert to #bot-alerts. Staff can check with `/econ-admin tick-status` and retry with `/econ-admin tick-run`.

**Catch-up after downtime:** missed days are processed in order. Days processed late still collect wages, rent and premiums, but late fees, missed-payment marks, evictions and policy lapses are skipped for them. Only the newest report is posted (setting `CATCHUP_PUBLISH_ALL=true` posts all of them).

Daylight-saving changes are handled by the time-zone calendar (tested).

## 4. Citizens, jobs and income

- A citizen account opens on the first economy command. The **starting grant** is 2,500 KGD (policy, 0–5,000).
- **One paid shift per economic day** with `/work`. The wage is paid at the daily tick.
- **Public-sector jobs** come from Discord roles (Police, EMS, Secretaries …). Wages are 350–1,000 KGD per day and paid by the treasury from the matching budget line. See [02-role-hierarchy.md](02-role-hierarchy.md) for the full list.
- **Private jobs** are posted by businesses (wage between the minimum wage of 150 KGD and the maximum of 2,500 KGD per day; max 10 open postings per business; 1–20 positions per posting). Unemployed citizens apply with `/jobs apply`.
- **Income tax** 10% is withheld from every wage.
- If an employer cannot pay, the shift stays unpaid and is retried for 7 days; the report shows unpaid wages.

## 5. Businesses

- **Registration:** `/business register` → review by the business registry (`/registry approve`). The **registration fee** (1,000 KGD) is charged only on approval. Nobody can approve their own business. Max 2 businesses per owner, max 5 managers per business.
- The registry may give the state an **ownership share** (0–100%) when approving; it receives that share of every profit distribution.
- **Industries and daily licence fees:** Mining 150, Timber 100, Tobacco 80, Cattle 80, Transport 60, Retail 50, Construction 70, Property management 50, Financial services 120 KGD. Seven days of unpaid fees suspend the business; paying the arrears lifts the suspension automatically.
- **Production** (mining, timber, tobacco, cattle): each paid shift at the business produces goods (max 8 shifts per business per day count). Output per shift: gold 13 g, diamonds 5 ct, palladium 26 g, timber 15 m³, tobacco 64 kg, beef 100 kg. Production costs (extraction and fuel, priced at the current exchange and fuel price) are paid by the business; if money is short, it produces less.
- **Turnover tax** 5% on payments a business receives. **Distribution tax** 10% when the owner withdraws profit.
- **Closing** pays out the remaining balance (as a distribution) and ends all employments.

## 6. Trade and markets

Kagundi is landlocked: imports carry 6% transport cost on top of the world price.

| Commodity | Unit | Base world price (EUR) | Daily volatility | Trade |
|---|---|---|---|---|
| Gold | g | 14.00 | 1.2% | Export (duty 8%) |
| Diamonds | ct | 35.00 | 1.5% | Export (duty 10%) |
| Palladium | g | 7.00 | 1.8% | Export (duty 8%) |
| Timber | m³ | 12.00 | 0.8% | Export (duty 5%) |
| Tobacco | kg | 2.80 | 1.0% | Export (duty 6%) |
| Beef | kg | 1.80 | 0.8% | Export (duty 4%) |
| Fuel | L | 0.90 | 1.2% | Import (tariff 5%) |
| Food & Essentials | crate | 4.00 | 0.6% | Import (tariff 8%) |
| Construction Materials | t | 60.00 | 0.7% | Import (tariff 6%) |

**Trade partners:** Germany (reference prices), European Union (pays 1.5% less, sells 1% dearer), China (pays 3% less, sells 4% cheaper). Each partner also has a demand index that drifts slowly between 0.85 and 1.15.

**Price model (per day):** pull back towards the base price (5–8% of the gap) + random move + active event drift. Heavy exports above the usual daily volume push the next day's price down. Every move is capped at **±4% per day**, and prices stay between **50% and 200%** of the base price.

**Exchange rate** (start 10.000 KGD per EUR): faster money growth weakens the dinar; a policy rate above 6% and a trade surplus strengthen it. Max ±0.5% per day; limits 5–30 KGD per EUR.

**Consumer price index** (launch = 100): food 50%, fuel 25%, construction materials 15%, rent 10%, using import prices including tariffs. Inflation in the report is measured over 30 days (or since launch in the first month).

## 7. Banking and credit

**Credit score:** 300–850, everyone starts at **600**. Recalculated every day from payment history (on-time payments up, missed payments, defaults, evictions and overdue fines down), current defaults, card utilisation, debt-to-income ratio, account age and activity.

| Band | Score | Interest rate* | Max loan | Card limit |
|---|---|---|---|---|
| Very Poor | 300–499 | 18% | none | none |
| Poor | 500–599 | 14% | 2,000 KGD | 500 KGD |
| Average | 600–699 | 10% | 10,000 KGD | 2,000 KGD |
| Good | 700–799 | 7% | 25,000 KGD | 5,000 KGD |
| Excellent | 800–850 | 5% | 50,000 KGD | 10,000 KGD |

\* At the neutral policy rate of 6%. Rate = band rate + (policy rate − 6%), never below 1%.

**Lending rules:**

- Monthly debt payments (all loans plus card minimum payments) may not exceed **35% of verified monthly net income** (wages, distributions and rent income of the last 30 days, after tax).
- At least 7 days of income history; max 2 active loans; no new credit while anything is in default.
- Terms 2–12 weeks, fixed weekly instalments (annuity). Interest accrues daily.
- Loans up to **5,000 KGD** that pass every check are paid out at once. Larger loans go to the Secretariat for Economy and Education (`/credit-office`), which re-checks every rule before approving.
- Missed instalment: late fee 2% (min 10 KGD) and a credit mark. After 4 missed instalments in a row the facility is in **default**.
- Credit card: minimum payment 10% of the balance (min 50 KGD) every week.

## 8. AVK – Allgemeine Volksversicherung Kagundi

| Product | Premium per day | Coverage | Deductible |
|---|---|---|---|
| Vehicle | 0.05% of insured value (min 1 KGD) | 1,000–250,000 KGD | 500 KGD |
| Property (own property only) | 0.01% of value | 5,000–2,000,000 KGD | 1,000 KGD |
| Business (own business only) | 0.02% of value | 5,000–1,000,000 KGD | 1,000 KGD |
| Liability | 15 KGD flat | 50,000 KGD | 250 KGD |
| Accident | 10 KGD flat | 20,000 KGD | none |
| Supplementary health (private treatment only) | 12 KGD flat | 15,000 KGD | 100 KGD |

Basic public healthcare stays free in roleplay; AVK health cover is only for private treatment.

**Anti-fraud rules (enforced by the bot):**

- **Waiting period:** no claims in the first 2 economic days of a policy.
- **Incident reference required** (police, Brandwehr or EMS report number) plus a description and evidence link.
- **One claim per incident per policy;** no duplicate policies for the same object.
- Payout never exceeds the claimed amount, the remaining coverage, minus the deductible.
- **AVK officers cannot decide claims on their own policies.** Each claim is paid **exactly once**; every decision needs a reason and is audited.
- Policies lapse after 3 days of unpaid premiums.
- AVK officers are encouraged to compare the reference with the service's records (in #avk-office) before approving.

## 9. Property

- 16 state properties exist at launch in Gundiville, Stokondo, Kagundali and Oberdueshuson (homes from 100 KGD rent per day, offices, shops, a warehouse, an industrial lot and tobacco fields; three are for sale).
- Rent is paid daily. After **3 missed days** the tenancy ends (eviction, credit mark). Rent can only be changed while a property is vacant.
- **Property tax** 1.5% of the value per year (charged daily; unpaid tax accumulates). **Transfer tax** 2% on every sale.
- Authorised officials (Secretary for Internal Affairs, Economic Administrators) can create new state property.

## 10. Public finance

- **Revenue:** income tax, turnover tax, distribution tax, export duties, import tariffs, property and transfer tax, registration and licence fees, fines, state rents and property sales, state dividends.
- **Expenditure:** public wages (automatic) and discretionary spending (`/treasury spend`, invoices to the state).
- **Budget:** 11 budget lines (administration, police and gendarmerie, defence, justice, healthcare, Brandwehr, education, infrastructure, public services and AVK, procurement, other) for 30-day periods. Spending is tracked against each line.
- **Two-person rule:** payments above **25,000 KGD** need a second authorised official (`/treasury approve`); nobody can approve their own request.
- **Central Bank financing** (printing money for the treasury) is Owner-only, audited and shows up in the report and in the exchange rate.

## 11. Policy levers

Changed with `/policy` by the Secretary for Economy and Education, the Secretary-General or the Leader. Every change needs a reason, is audited and appears in the next report.

| Lever | Default | Allowed range |
|---|---|---|
| Central bank policy rate | 6% | 0–25% |
| Income tax | 10% | 0–40% |
| Turnover tax | 5% | 0–20% |
| Distribution tax | 10% | 0–30% |
| Property tax (per year) | 1.5% | 0–5% |
| Property transfer tax | 2% | 0–10% |
| Business registration fee | 1,000 KGD | 0–20,000 KGD |
| Minimum daily wage | 150 KGD | 0–1,000 KGD |
| Maximum private daily wage | 2,500 KGD | 500–10,000 KGD |
| Starting grant | 2,500 KGD | 0–5,000 KGD |
| Import tariff (per commodity) | 5–8% | 0–50% |
| Export duty (per commodity) | 4–10% | 0–40% |
| Export ban (per commodity) | none | on/off |

## 12. Fines and invoices

- **Fines:** issued by City Police, Gendarmerie and Judges (max 50,000 KGD; larger penalties need a court judgment). Due after 3 days, then collected automatically from the bank account if possible; overdue fines hurt the credit score. Judges and Economic Administrators can cancel a fine, for example after an appeal (appeals within 72 hours).
- **Invoices:** businesses bill citizens, other businesses or the state (max 1,000,000 KGD). Goods on an invoice leave the seller's stock when it is paid. Unpaid invoices expire after 7 days.

## 13. Economic events

14 events in the catalogue (gold demand surge, diamond slump, mine flooding, drought, fuel price spike, highway disruption, German trade mission, weaker Chinese demand and more). Events **never move money directly**; they only change prices, output per shift, production costs or partner demand, within hard limits:

- price drift at most ±3% per day, output and cost multipliers 0.5–1.5, partner demand 0.8–1.2, duration 1–30 days;
- at most 2 random events at the same time; each event has a cooldown; the same event never overlaps itself;
- 12 events can start randomly (1–2% chance per day each), 2 only by staff (`/econ-admin event-start`, needs a reason, audited).

## 14. National Economic Report

Posted every day after midnight to #national-economic-report, with the commodity board in #commodity-markets. Sections: National indicators (GDP est., 7-day average, CPI and inflation, unemployment est., exchange rate, money stock), Public finance, Industry and trade (price table, exports and imports by partner), Financial conditions, Labour and business, three Daily developments, Risks, Opportunities, Economic outlook. Signed by the Secretariat for Economy and Education.

- **GDP (est.)** = value of production + sales to households and the state + public wages + housing payments of that day.
- **Unemployment (est.)** = share of citizens active in the last 7 days who neither worked a shift nor hold a job.
- The report is stored when the day is processed. Re-posting never changes its numbers.

## 15. Abuse protection

- Command cooldown (3 seconds per member), input limits on every amount and text.
- Starting grant once per Discord account, only for accounts at least 14 days old.
- No self-approval anywhere (business registry, spending, AVK claims); no self-fines.
- Frozen accounts (`/econ-admin freeze`) block voluntary payments; scheduled obligations still run.
- Maintenance mode (Owner) pauses all player actions without stopping reading.
- Every sensitive action (corrections, freezes, inspections, policy, spending, approvals, events) is written to the audit log with actor, reason and old/new values, and mirrored to #economy-audit-log.

## 16. Calibration (from the offline simulation)

`npm run simulate -- 30` runs 30 days with 10 simulated players (2 business owners, 3 workers, 2 police officers, 1 paramedic, 1 official, 1 Secretary). Results on day 30: the books balanced, CPI 103.1 (+3.1% in 30 days), exchange rate 10.055, treasury about 1.45 million KGD with a daily deficit of about 1,600 KGD (public wages 3,300 KGD vs. revenue 1,700 KGD).

What this means for 20–25 players (estimate): if about half of them hold public jobs, public wages are roughly 7,000–9,000 KGD per day. The launch treasury of 1.5 million KGD then lasts several months even with little revenue, which gives the government time to build a tax base. Levers if the deficit becomes a problem: raise taxes or duties, cut public wages (`/treasury wage`), or (Owner only) Central Bank financing, which weakens the dinar and raises prices. These numbers should be reviewed after the first two weeks of real play.
