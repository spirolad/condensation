import { Registry, Counter, Gauge, collectDefaultMetrics } from 'prom-client';

const globalAny: any = globalThis as any;

function safeCreateRegistry() {
  if (!globalAny.__prom_registry__) {
    const registry = new Registry();
    try {
      if (typeof (globalThis as any).Bun === 'undefined') {
        collectDefaultMetrics({ register: registry });
      }
    } catch (err) {
    }
    globalAny.__prom_registry__ = registry;
  }
  return globalAny.__prom_registry__ as Registry;
}

function safeCreateMetrics(registry: Registry) {
  if (!globalAny.__prom_request_counter__) {
    const req = new Counter({ name: 'frontend_http_requests_total', help: 'Total HTTP requests received by frontend', registers: [registry] });
    globalAny.__prom_request_counter__ = req;
  }
  if (!globalAny.__prom_uptime_gauge__) {
    const gauge = new Gauge({ name: 'frontend_process_uptime_seconds', help: 'Process uptime in seconds', registers: [registry] });
    globalAny.__prom_uptime_gauge__ = gauge;
  }
  if (!globalAny.__prom_start_time__) {
    globalAny.__prom_start_time__ = Date.now();
  }
}

export function getRegistry(): Registry {
  const r = safeCreateRegistry();
  safeCreateMetrics(r);
  return r;
}

export function getRequestCounter() {
  return globalAny.__prom_request_counter__ as Counter<string>;
}

export function updateUptimeGauge() {
  const gauge = globalAny.__prom_uptime_gauge__ as Gauge<string> | undefined;
  const start = globalAny.__prom_start_time__ as number | undefined;
  if (gauge && start) {
    const seconds = (Date.now() - start) / 1000;
    gauge.set(seconds);
  }
}

