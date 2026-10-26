// Economic calendar. Economic day 1 is the launch date. A day runs from 00:00 to 24:00 in the
// configured timezone (default Europe/Berlin) and is processed by the tick right after it ends.

const MS_PER_DAY = 86_400_000;

export function localDateString(date, timeZone) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone, year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(date);
  const get = (type) => parts.find((p) => p.type === type).value;
  return `${get('year')}-${get('month')}-${get('day')}`;
}

function dateToUtcMs(dateString) {
  const [y, m, d] = dateString.split('-').map(Number);
  return Date.UTC(y, m - 1, d);
}

export function addDays(dateString, days) {
  return new Date(dateToUtcMs(dateString) + days * MS_PER_DAY).toISOString().slice(0, 10);
}

export function daysBetween(fromDate, toDate) {
  return Math.round((dateToUtcMs(toDate) - dateToUtcMs(fromDate)) / MS_PER_DAY);
}

export function createClock({ timeZone = 'Europe/Berlin', now = () => new Date() } = {}) {
  // Validate the timezone early so a typo fails at startup, not at midnight.
  localDateString(new Date(), timeZone);
  let genesisDate = null;
  return {
    timeZone,
    now,
    setGenesis(date) { genesisDate = date; },
    get genesisDate() { return genesisDate; },
    todayDate() { return localDateString(now(), timeZone); },
    // Current economic day number (1 = launch day).
    today() {
      if (!genesisDate) throw new Error('Economy has no launch date yet.');
      return daysBetween(genesisDate, localDateString(now(), timeZone)) + 1;
    },
    dateOfDay(day) {
      if (!genesisDate) throw new Error('Economy has no launch date yet.');
      return addDays(genesisDate, day - 1);
    },
    isoNow() { return now().toISOString(); },
  };
}
