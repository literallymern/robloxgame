// Offline simulation: runs the economy for a number of days with a few simulated players and
// prints the national economic report. No Discord connection or token is needed.
//
//   npm run simulate             (14 days, in-memory database)
//   npm run simulate -- 30       (30 days)
import { createEconomy } from '../src/economy/index.js';
import { ensureCitizen } from '../src/economy/citizens.js';
import { registerBusiness, approveBusiness, sellExport, buyImport, depositToBusiness, withdrawFromBusiness } from '../src/economy/businesses.js';
import { postJob, applyForJob, hire, clockIn } from '../src/economy/employment.js';
import { rentProperty, listProperties } from '../src/economy/property.js';
import { buyPolicy } from '../src/economy/insurance.js';
import { applyForLoan } from '../src/economy/credit.js';
import { setBudget, requestSpending } from '../src/economy/treasury.js';
import { issueFine } from '../src/economy/fines.js';
import { catchUp, latestReport } from '../src/economy/tick.js';
import { reportToMarkdown } from '../src/economy/report.js';
import { verifyLedger } from '../src/economy/ledger.js';
import { personalAccountId } from '../src/economy/citizens.js';
import { KGD } from '../src/economy/constants.js';

const days = Number(process.argv[2] ?? 14);
let now = new Date('2026-11-01T10:00:00Z');
const eco = createEconomy({ now: () => now, seed: 'simulation-seed', logger: { info() {}, warn() {}, error: console.error } });
const advanceDay = () => { now = new Date(now.getTime() + 86_400_000); };
const safe = (fn) => { try { return fn(); } catch (e) { return { error: e.message }; } };

const players = ['owner1', 'owner2', 'worker1', 'worker2', 'worker3', 'police1', 'police2', 'ems1', 'official1', 'secretary'];
for (const id of players) ensureCitizen(eco, { userId: id, displayName: id, grantEligible: true });

// Two businesses: a gold mine and a tobacco farm.
const mine = registerBusiness(eco, { ownerId: 'owner1', name: 'Kagundali Gold Works', industry: 'mining', output: 'gold' });
const farm = registerBusiness(eco, { ownerId: 'owner2', name: 'Oberdueshuson Tobacco Co', industry: 'tobacco' });
approveBusiness(eco, { id: mine.id, actor: 'official1' });
approveBusiness(eco, { id: farm.id, actor: 'official1' });
const mineJob = postJob(eco, { businessId: mine.id, actor: 'owner1', title: 'Miner', wage: KGD(550), slots: 3 });
const farmJob = postJob(eco, { businessId: farm.id, actor: 'owner2', title: 'Farm Hand', wage: KGD(450), slots: 2 });
for (const w of ['worker1', 'worker2']) hire(eco, { applicationId: applyForJob(eco, { jobId: mineJob.id, userId: w }).id, actor: 'owner1' });
hire(eco, { applicationId: applyForJob(eco, { jobId: farmJob.id, userId: 'worker3' }).id, actor: 'owner2' });
depositToBusiness(eco, { businessId: mine.id, userId: 'owner1', amount: KGD(1200) });
depositToBusiness(eco, { businessId: farm.id, userId: 'owner2', amount: KGD(1200) });

const homes = listProperties(eco).filter((p) => p.type === 'residential' && !p.tenant_id);
['worker1', 'worker2', 'police1'].forEach((u, i) => rentProperty(eco, { userId: u, propertyId: homes[i].id }));
buyPolicy(eco, { userId: 'police1', product: 'vehicle', insuredValue: KGD(20000), description: 'Patrol car KG-001' });
setBudget(eco, { actor: 'secretary', category: 'infrastructure', amount: KGD(100000), reason: 'Monthly road maintenance' });

const roles = { police1: ['city_police'], police2: ['city_police'], ems1: ['ems'], official1: ['government_official'], secretary: ['secretary_economy'] };

for (let d = 1; d <= days; d++) {
  for (const id of players) {
    if (id.startsWith('owner') && d % 3 !== 0) continue;
    safe(() => clockIn(eco, { userId: id, roleKeys: roles[id] ?? [] }));
  }
  if (d >= 2) {
    safe(() => sellExport(eco, { businessId: mine.id, userId: 'owner1', commodity: 'gold', quantity: 20, partner: 'germany' }));
    safe(() => sellExport(eco, { businessId: farm.id, userId: 'owner2', commodity: 'tobacco', quantity: 60, partner: 'china' }));
  }
  if (d === 4) safe(() => buyImport(eco, { businessId: mine.id, userId: 'owner1', commodity: 'fuel', quantity: 200, partner: 'germany' }));
  if (d === 5) safe(() => issueFine(eco, { issuerId: 'police1', authority: 'City Police', userId: 'worker2', amount: KGD(150), reason: 'Speeding in Gundiville' }));
  if (d === 6) safe(() => requestSpending(eco, { actor: 'secretary', payeeAccount: personalAccountId(eco, 'official1', 'bank'), amount: KGD(2000), category: 'infrastructure', reason: 'Road survey contract' }));
  if (d === 9) console.log('Loan application (worker1):', JSON.stringify(safe(() => applyForLoan(eco, { applicantId: 'worker1', amount: KGD(1500), weeks: 4, purpose: 'Car' })).status ?? 'error'));
  if (d === 10) safe(() => withdrawFromBusiness(eco, { businessId: mine.id, userId: 'owner1', amount: KGD(1000) }));
  advanceDay();
  catchUp(eco);
}

const report = latestReport(eco);
console.log(reportToMarkdown(report.content));
const check = verifyLedger(eco);
console.log(`\nLedger check: ${check.ok ? 'OK' : 'FAILED'} (sum of all balances = ${check.sum})`);
eco.close();
