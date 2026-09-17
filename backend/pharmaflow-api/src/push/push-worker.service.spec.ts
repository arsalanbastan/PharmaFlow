import { pushRetryDelayMs, pushTargetKey } from './push-worker.service';

describe('PushWorkerService helpers', () => {
  it('creates a stable non-plaintext target key for one installation', () => {
    const first = pushTargetKey({
      userId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      installationId: 'install-12345678',
      appPackage: 'com.example.pharmaflow.dev',
    });

    const second = pushTargetKey({
      userId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      installationId: 'install-12345678',
      appPackage: 'com.example.pharmaflow.dev',
    });

    expect(first).toBe(second);
    expect(first).toMatch(/^[0-9a-f]{64}$/);
    expect(first).not.toContain('install-12345678');
  });

  it('uses bounded exponential retry delays', () => {
    expect(pushRetryDelayMs(1)).toBe(30_000);
    expect(pushRetryDelayMs(2)).toBe(60_000);
    expect(pushRetryDelayMs(5)).toBe(480_000);
    expect(pushRetryDelayMs(10)).toBe(600_000);
  });
});
