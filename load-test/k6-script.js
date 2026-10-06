// Load test for the deployed app: ramps traffic up past what one task per
// service can handle, holds it long enough for target tracking to scale out,
// then drops it so scale-in can be observed. Run with load-test/run-load-test.sh.
import http from "k6/http";
import { check, sleep } from "k6";

const BASE_URL = __ENV.BASE_URL;
const PEAK_RPS = Number(__ENV.PEAK_RPS || 60);
const MOVIES_TO_SEED = 20;

const params = {
  headers: {
    Authorization: `Bearer ${__ENV.ACCESS_TOKEN}`,
    "Content-Type": "application/json",
  },
};

export const options = {
  // The load balancer uses a self-signed certificate unless a domain is set.
  insecureSkipTLSVerify: true,
  scenarios: {
    ramp: {
      // Arrival rate (requests started per second) rather than a fixed number
      // of users, so the offered load stays the same even when responses slow
      // down - which is exactly when scaling should kick in.
      executor: "ramping-arrival-rate",
      startRate: 1,
      timeUnit: "1s",
      preAllocatedVUs: 50,
      maxVUs: 400,
      stages: [
        { duration: "2m", target: Math.ceil(PEAK_RPS / 3) }, // warm-up
        { duration: "3m", target: PEAK_RPS }, // ramp to peak
        { duration: "10m", target: PEAK_RPS }, // hold: scale-out happens here
        { duration: "2m", target: 0 }, // ramp down; scale-in follows ~15 min later
      ],
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.05"],
    http_req_duration: ["p(95)<2000"],
  },
};

// Seeds a fixed set of movies once, so reads hit a small, stable table
// instead of one that grows (and slows down) during the test.
export function setup() {
  const ids = [];
  for (let i = 0; i < MOVIES_TO_SEED; i++) {
    const res = http.post(
      `${BASE_URL}/api/movies`,
      JSON.stringify({ title: `load-test-movie-${i}`, description: "seeded by k6" }),
      params,
    );
    if (res.status !== 201) {
      throw new Error(`Seeding failed: POST /api/movies returned ${res.status} ${res.body}`);
    }
    ids.push(res.json("id"));
  }
  return { ids };
}

// Traffic mix: 60% list, 20% get by id, 20% billing orders (through RabbitMQ).
export default function (data) {
  const roll = Math.random();

  if (roll < 0.6) {
    const res = http.get(`${BASE_URL}/api/movies?title=load-test-movie`, {
      ...params,
      tags: { name: "GET /api/movies" },
    });
    check(res, { "list movies 200": (r) => r.status === 200 });
  } else if (roll < 0.8) {
    const id = data.ids[Math.floor(Math.random() * data.ids.length)];
    const res = http.get(`${BASE_URL}/api/movies/${id}`, {
      ...params,
      tags: { name: "GET /api/movies/{id}" },
    });
    check(res, { "get movie 200": (r) => r.status === 200 });
  } else {
    const order = {
      user_id: `load-test-${__VU}`,
      number_of_items: 1 + Math.floor(Math.random() * 5),
      total_amount: Math.round(Math.random() * 10000) / 100,
    };
    const res = http.post(`${BASE_URL}/api/billing`, JSON.stringify(order), {
      ...params,
      tags: { name: "POST /api/billing" },
    });
    check(res, { "billing order 200": (r) => r.status === 200 });
  }

  sleep(0.1);
}
