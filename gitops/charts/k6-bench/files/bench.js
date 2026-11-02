// k6 benchmark against the challenge app - TARGET is set per round namespace.
// SCENARIO=fast|slow|random|all - each scenario runs DURATION (constant VUs); "all" runs the three one after another.
// Profiles come from the chart values (env FAST_VUS, SLOW_MIN_WAIT, ... - defaults below match values.yaml).
// The wait range is passed as ?minWait=<n>&maxWait=<n> (the app picks a random value in it); apps that ignore it (round 1 nginx) just answer.
import http from 'k6/http';
import { check } from 'k6';

const TARGET = __ENV.TARGET;
const SCENARIO = __ENV.SCENARIO || 'all';

const num = (name, fallback) => Number(__ENV[name] || fallback);

// seconds per scenario
const DURATION = num('DURATION', 90);

const PROFILES = {
  fast: { vus: 20, minWait: 10, maxWait: 100 },
  slow: { vus: 5, minWait: 1000, maxWait: 2000 },
  random: { vus: 10, minWait: 200, maxWait: 1500 },
};

// apply env overrides: <PROFILE>_VUS, _MIN_WAIT, _MAX_WAIT
for (const [name, p] of Object.entries(PROFILES)) {
  const prefix = name.toUpperCase();
  p.vus = num(`${prefix}_VUS`, p.vus);
  p.minWait = num(`${prefix}_MIN_WAIT`, p.minWait);
  p.maxWait = num(`${prefix}_MAX_WAIT`, p.maxWait);
}

const selected = SCENARIO === 'all' ? Object.keys(PROFILES) : [SCENARIO];

// in series: the i-th selected scenario starts after the previous ones finished
const SCENARIOS = Object.fromEntries(
  selected.map((name, i) => [
    name,
    {
      executor: 'constant-vus',
      exec: name,
      vus: PROFILES[name].vus,
      duration: `${DURATION}s`,
      startTime: `${i * DURATION}s`,
      gracefulStop: '30s',
    },
  ]),
);

export const options = {
  scenarios: SCENARIOS,
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
  // always-passing thresholds, only to get a per-scenario breakdown in the summary
  thresholds: Object.fromEntries(
    selected.flatMap((s) => [
      [`http_req_duration{scenario:${s}}`, ['max>=0']],
      [`http_req_failed{scenario:${s}}`, ['rate>=0']],
    ]),
  ),
};

function hit(p) {
  const res = http.get(`${TARGET}/?minWait=${p.minWait}&maxWait=${p.maxWait}`, { timeout: '30s' });
  check(res, { 'status 200': (r) => r.status === 200 });
}

export function fast() { hit(PROFILES.fast); }
export function slow() { hit(PROFILES.slow); }
export function random() { hit(PROFILES.random); }
