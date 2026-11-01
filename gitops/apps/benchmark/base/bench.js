// k6 benchmark against the challenge app - TARGET is set per variant namespace.
// SCENARIO=fast|slow|random|all - "all" runs the three in parallel.
// The requested duration is passed as ?ms=<n>; apps that ignore it (round 1 nginx) just answer.
import http from 'k6/http';
import { check } from 'k6';

const TARGET = __ENV.TARGET;
const SCENARIO = __ENV.SCENARIO || 'all';

const rnd = (min, max) => Math.floor(min + Math.random() * (max - min + 1));

const SCENARIOS = {
  fast: { executor: 'shared-iterations', exec: 'fast', iterations: 1000, vus: 20, maxDuration: '10m' },
  slow: { executor: 'shared-iterations', exec: 'slow', iterations: 200, vus: 5, maxDuration: '10m' },
  random: { executor: 'shared-iterations', exec: 'random', iterations: 300, vus: 10, maxDuration: '10m' },
};

const selected = SCENARIO === 'all' ? Object.keys(SCENARIOS) : [SCENARIO];

export const options = {
  scenarios: Object.fromEntries(selected.map((s) => [s, SCENARIOS[s]])),
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
  // always-passing thresholds, only to get a per-scenario breakdown in the summary
  thresholds: Object.fromEntries(
    selected.flatMap((s) => [
      [`http_req_duration{scenario:${s}}`, ['max>=0']],
      [`http_req_failed{scenario:${s}}`, ['rate>=0']],
    ]),
  ),
};

function hit(ms) {
  const res = http.get(`${TARGET}/?ms=${ms}`, { timeout: '30s' });
  check(res, { 'status 200': (r) => r.status === 200 });
}

export function fast() { hit(rnd(10, 100)); }
export function slow() { hit(rnd(1000, 2000)); }
export function random() { hit(rnd(200, 1500)); }
