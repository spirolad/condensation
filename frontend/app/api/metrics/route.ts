

import { getRegistry, updateUptimeGauge } from '../../../lib/metrics';

const registry = getRegistry();

export async function GET() {
  try {
    updateUptimeGauge();
  } catch {}
  const metrics = await registry.metrics();
  return new Response(metrics, {
    status: 200,
    headers: { 'Content-Type': 'text/plain; version=0.0.4; charset=utf-8' },
  });
}


