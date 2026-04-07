import http from "k6/http";
import { check, sleep } from "k6";

export const options = {
  stages: [
    { duration: "10s", target: 50 }, // Ramp up to 50 users
    { duration: "30s", target: 50 }, // Stay at 50 users
    { duration: "5s", target: 0 }, // Ramp down to 0
  ],
  thresholds: {
    http_req_duration: ["p(95)<500"], // 95% of requests must complete within 500ms
    http_req_failed: ["rate<0.01"], // Error rate must be less than 1%
  },
};

export default function () {
  const res = http.get(`${__ENV.API_BASE_URL}/api/health`);
  check(res, { "status was 200": (r) => r.status == 200 });
  sleep(1);
}
