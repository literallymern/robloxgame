// Jobs, applications, employment, shifts and payroll.
import { BUSINESS_RULES } from './constants.js';
import { transfer, tryTransfer, systemAccountId } from './ledger.js';
import { personalAccountId, requireCitizen, touchCitizen } from './citizens.js';
import { getPolicy } from './policy.js';
import { applyBp, formatKGD } from './money.js';
import { requireBusinessAccess, getBusiness } from './businesses.js';
import { UserError, PermissionError } from './errors.js';
import { audit } from './audit.js';

const MAX_OPEN_JOBS_PER_BUSINESS = 10;

export function getJob(eco, id) {
  return eco.db.prepare('SELECT * FROM jobs WHERE id = ?').get(id) ?? null;
}

export function postJob(eco, { businessId, actor, title, wage, slots }) {
  const cleanTitle = String(title ?? '').trim();
  if (cleanTitle.length < 3 || cleanTitle.length > 60) throw new UserError('Job titles must be 3-60 characters.');
  if (!Number.isInteger(slots) || slots < 1 || slots > 20) throw new UserError('Positions must be between 1 and 20.');
  return eco.tx(() => {
    const b = requireBusinessAccess(eco, businessId, actor, 'manager', { allowSuspended: false });
    const min = getPolicy(eco, 'min_wage_daily');
    const max = getPolicy(eco, 'max_private_wage_daily');
    if (wage < min || wage > max) throw new UserError(`Daily wages must be between ${formatKGD(min)} and ${formatKGD(max)}.`);
    const open = eco.db.prepare("SELECT COUNT(*) AS n FROM jobs WHERE business_id = ? AND status = 'open'").get(businessId).n;
    if (open >= MAX_OPEN_JOBS_PER_BUSINESS) throw new UserError(`A business can have at most ${MAX_OPEN_JOBS_PER_BUSINESS} open job postings.`);
    const res = eco.db.prepare(`INSERT INTO jobs (employer_type, business_id, title, daily_wage, slots, status, created_by, created_day)
      VALUES ('business', ?, ?, ?, ?, 'open', ?, ?)`).run(businessId, cleanTitle, wage, slots, actor, eco.currentDay());
    return { id: Number(res.lastInsertRowid), business: b, title: cleanTitle, wage, slots };
  });
}

export function closeJob(eco, { jobId, actor }) {
  return eco.tx(() => {
    const job = getJob(eco, jobId);
    if (!job || job.employer_type !== 'business') throw new UserError('Job not found.');
    requireBusinessAccess(eco, job.business_id, actor, 'manager');
    eco.db.prepare("UPDATE jobs SET status = 'closed' WHERE id = ?").run(jobId);
    eco.db.prepare("UPDATE job_applications SET status = 'withdrawn' WHERE job_id = ? AND status = 'pending'").run(jobId);
    return job;
  });
}

function filledCount(eco, jobId) {
  return Number(eco.db.prepare("SELECT COUNT(*) AS n FROM employments WHERE job_id = ? AND status = 'active'").get(jobId).n);
}

// Public job board: open private-sector jobs.
export function openJobs(eco) {
  return eco.db.prepare(`SELECT j.*, b.name AS business_name, b.industry,
      (SELECT COUNT(*) FROM employments e WHERE e.job_id = j.id AND e.status = 'active') AS filled
    FROM jobs j JOIN businesses b ON b.id = j.business_id
    WHERE j.employer_type = 'business' AND j.status = 'open' AND b.status = 'active' ORDER BY j.daily_wage DESC, j.id`).all()
    .filter((j) => j.filled < j.slots);
}

export function stateJobs(eco) {
  return eco.db.prepare("SELECT * FROM jobs WHERE employer_type = 'state' ORDER BY daily_wage DESC").all();
}

export function applyForJob(eco, { jobId, userId, message }) {
  return eco.tx(() => {
    requireCitizen(eco, userId, 'You');
    const job = getJob(eco, jobId);
    if (!job || job.employer_type !== 'business' || job.status !== 'open') throw new UserError('This job is not open for applications.');
    const b = getBusiness(eco, job.business_id);
    if (b.status !== 'active') throw new UserError('This business is not hiring at the moment.');
    if (eco.db.prepare("SELECT 1 FROM employments WHERE job_id = ? AND user_id = ? AND status = 'active'").get(jobId, userId)) throw new UserError('You already work in this position.');
    if (filledCount(eco, jobId) >= job.slots) throw new UserError('All positions for this job are filled.');
    if (eco.db.prepare("SELECT 1 FROM job_applications WHERE job_id = ? AND user_id = ? AND status = 'pending'").get(jobId, userId)) throw new UserError('You already applied for this job.');
    const res = eco.db.prepare(`INSERT INTO job_applications (job_id, user_id, message, status, created_day) VALUES (?, ?, ?, 'pending', ?)`)
      .run(jobId, userId, message ? String(message).slice(0, 300) : null, eco.currentDay());
    touchCitizen(eco, userId);
    return { id: Number(res.lastInsertRowid), job, business: b };
  });
}

export function applicationsFor(eco, businessId) {
  return eco.db.prepare(`SELECT a.*, j.title, j.daily_wage FROM job_applications a JOIN jobs j ON j.id = a.job_id
    WHERE j.business_id = ? AND a.status = 'pending' ORDER BY a.id`).all(businessId);
}

export function hire(eco, { applicationId, actor }) {
  return eco.tx(() => {
    const app = eco.db.prepare('SELECT * FROM job_applications WHERE id = ?').get(applicationId);
    if (!app || app.status !== 'pending') throw new UserError('Application not found or already decided.');
    const job = getJob(eco, app.job_id);
    const b = requireBusinessAccess(eco, job.business_id, actor, 'manager', { allowSuspended: false });
    if (job.status !== 'open') throw new UserError('This job posting is closed.');
    if (filledCount(eco, job.id) >= job.slots) throw new UserError('All positions for this job are filled.');
    eco.db.prepare("UPDATE job_applications SET status = 'accepted', decided_by = ?, decided_day = ? WHERE id = ?").run(actor, eco.currentDay(), applicationId);
    eco.db.prepare("INSERT INTO employments (job_id, user_id, status, start_day) VALUES (?, ?, 'active', ?)").run(job.id, app.user_id, eco.currentDay());
    return { userId: app.user_id, job, business: b };
  });
}

export function rejectApplication(eco, { applicationId, actor }) {
  return eco.tx(() => {
    const app = eco.db.prepare('SELECT * FROM job_applications WHERE id = ?').get(applicationId);
    if (!app || app.status !== 'pending') throw new UserError('Application not found or already decided.');
    const job = getJob(eco, app.job_id);
    requireBusinessAccess(eco, job.business_id, actor, 'manager');
    eco.db.prepare("UPDATE job_applications SET status = 'rejected', decided_by = ?, decided_day = ? WHERE id = ?").run(actor, eco.currentDay(), applicationId);
    return { userId: app.user_id, job };
  });
}

export function fire(eco, { businessId, actor, userId }) {
  return eco.tx(() => {
    const b = requireBusinessAccess(eco, businessId, actor, 'manager');
    const res = eco.db.prepare(`UPDATE employments SET status = 'ended', end_day = ?, end_reason = 'dismissed'
      WHERE status = 'active' AND user_id = ? AND job_id IN (SELECT id FROM jobs WHERE business_id = ?)`).run(eco.currentDay(), userId, businessId);
    if (!res.changes) throw new UserError('That person does not work for this business.');
    return b;
  });
}

export function quitJob(eco, { userId, jobId }) {
  return eco.tx(() => {
    const res = eco.db.prepare(`UPDATE employments SET status = 'ended', end_day = ?, end_reason = 'resigned'
      WHERE status = 'active' AND user_id = ? AND job_id = ?`).run(eco.currentDay(), userId, jobId);
    if (!res.changes) throw new UserError('You do not hold that job.');
    return getJob(eco, jobId);
  });
}

// All jobs a citizen may work today: private employments plus public jobs for the Discord roles they hold.
export function eligibleJobs(eco, userId, roleKeys = []) {
  const privateJobs = eco.db.prepare(`SELECT j.*, b.name AS business_name FROM employments e JOIN jobs j ON j.id = e.job_id JOIN businesses b ON b.id = j.business_id
    WHERE e.user_id = ? AND e.status = 'active' AND b.status IN ('active','suspended') ORDER BY j.daily_wage DESC`).all(userId);
  const keys = [...new Set(roleKeys)];
  const publicJobs = keys.length
    ? eco.db.prepare(`SELECT * FROM jobs WHERE employer_type = 'state' AND department IN (${keys.map(() => '?').join(',')}) ORDER BY daily_wage DESC`).all(...keys)
    : [];
  return [...publicJobs, ...privateJobs];
}

// Registers today's shift. A citizen can be paid for one shift per economic day.
export function clockIn(eco, { userId, roleKeys = [], jobId = null }) {
  return eco.tx(() => {
    requireCitizen(eco, userId, 'You');
    const day = eco.currentDay();
    const existing = eco.db.prepare('SELECT s.*, j.title FROM shifts s JOIN jobs j ON j.id = s.job_id WHERE s.econ_day = ? AND s.user_id = ?').get(day, userId);
    if (existing) throw new UserError(`You already registered a shift today (${existing.title}). You can work one paid shift per economic day.`);
    const jobs = eligibleJobs(eco, userId, roleKeys);
    if (!jobs.length) throw new UserError('You have no job yet. Find one with /jobs list, or join a public service through its application process.');
    let job;
    if (jobId) {
      job = jobs.find((j) => j.id === jobId);
      if (!job) throw new PermissionError('You are not employed in that job.');
    } else if (jobs.length === 1) {
      job = jobs[0];
    } else {
      throw new UserError(`You have several jobs. Choose one with the job option: ${jobs.map((j) => `#${j.id} ${j.title}`).join(', ')}`);
    }
    eco.db.prepare(`INSERT INTO shifts (econ_day, user_id, job_id, business_id, gross, status, created_at) VALUES (?, ?, ?, ?, ?, 'pending', ?)`)
      .run(day, userId, job.id, job.business_id ?? null, job.daily_wage, eco.clock.isoNow());
    touchCitizen(eco, userId);
    return { job, day };
  });
}

// Pays the shifts of `day` and retries unpaid shifts from the last few days.
// Wages are paid gross by the employer; income tax is then withheld from the employee for the treasury.
export function processPayroll(eco, day) {
  const out = { paid: 0, unpaid: 0, grossPrivate: 0, grossPublic: 0, tax: 0, shifts: 0 };
  const treasury = systemAccountId(eco, 'treasury');
  const taxBp = getPolicy(eco, 'income_tax_bp');
  const shifts = eco.db.prepare(`SELECT s.*, j.employer_type, j.budget, j.title FROM shifts s JOIN jobs j ON j.id = s.job_id
    WHERE s.status IN ('pending','unpaid') AND s.econ_day <= ? AND s.econ_day >= ? ORDER BY s.econ_day, s.id`).all(day, day - BUSINESS_RULES.unpaidShiftRetryDays);
  for (const s of shifts) {
    if (s.econ_day === day) out.shifts += 1;
    const isPublic = s.employer_type === 'state';
    const employerAccount = isPublic ? treasury : getBusiness(eco, s.business_id)?.account_id;
    const employee = personalAccountId(eco, s.user_id, 'bank');
    const paid = employerAccount && tryTransfer(eco, {
      from: employerAccount, to: employee, amount: s.gross, system: true, day,
      category: isPublic ? `public_wage:${s.budget ?? 'administration'}` : 'wage',
      memo: `Wage for ${s.title}, economic day ${s.econ_day}`, refType: 'shift', refId: s.id, key: `wage:${s.id}`,
    });
    if (!paid) {
      eco.db.prepare("UPDATE shifts SET status = 'unpaid' WHERE id = ?").run(s.id);
      out.unpaid += 1;
      continue;
    }
    const tax = applyBp(s.gross, taxBp);
    if (tax > 0) {
      transfer(eco, { from: employee, to: treasury, amount: tax, system: true, day, category: 'income_tax',
        memo: `Income tax withheld, shift #${s.id}`, refType: 'shift', refId: s.id, key: `incometax:${s.id}` });
    }
    eco.db.prepare("UPDATE shifts SET status = 'paid', tax = ?, net = ?, paid_day = ? WHERE id = ?").run(tax, s.gross - tax, day, s.id);
    out.paid += 1;
    out.tax += tax;
    if (isPublic) out.grossPublic += s.gross; else out.grossPrivate += s.gross;
  }
  return out;
}

export function setPublicWage(eco, { department, wage, actor, reason }) {
  if (!reason || reason.trim().length < 5) throw new UserError('Please give a reason (at least 5 characters).');
  if (!Number.isInteger(wage) || wage < 100 || wage > 1000000) throw new UserError('Public wages must be between 1.00 and 10,000.00 KGD per day.');
  return eco.tx(() => {
    const job = eco.db.prepare("SELECT * FROM jobs WHERE employer_type = 'state' AND department = ?").get(department);
    if (!job) throw new UserError('Unknown public-sector department.');
    eco.db.prepare('UPDATE jobs SET daily_wage = ? WHERE id = ?').run(wage, job.id);
    audit(eco, { actor, action: 'treasury.public_wage', target: department, oldValue: job.daily_wage, newValue: wage, reason });
    return { job, old: job.daily_wage, wage };
  });
}

export function myEmployments(eco, userId) {
  return eco.db.prepare(`SELECT e.*, j.title, j.daily_wage, b.name AS business_name FROM employments e JOIN jobs j ON j.id = e.job_id
    LEFT JOIN businesses b ON b.id = j.business_id WHERE e.user_id = ? AND e.status = 'active'`).all(userId);
}

export function recentShifts(eco, userId, limit = 7) {
  return eco.db.prepare('SELECT s.*, j.title FROM shifts s JOIN jobs j ON j.id = s.job_id WHERE s.user_id = ? ORDER BY s.econ_day DESC LIMIT ?').all(userId, limit);
}
