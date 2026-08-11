type JsonLike = Record<string, unknown>;

const SENSITIVE_KEYS = new Set([
  'amount',
  'apiKey',
  'authorization',
  'chequeNumber',
  'id',
  'imageData',
  'nationalId',
  'password',
  'refreshToken',
  'secret',
  'token',
  'uuid',
]);

function estimateBase64Kilobytes(value: string): number {
  const dataPart = value.includes(',') ? value.split(',').pop() ?? '' : value;
  const normalized = dataPart.replace(/\s/g, '');

  if (!normalized) {
    return 0;
  }

  const padding = normalized.endsWith('==')
    ? 2
    : normalized.endsWith('=')
      ? 1
      : 0;
  const bytes = Math.max(0, Math.floor((normalized.length * 3) / 4) - padding);

  return Math.ceil(bytes / 1024);
}

function sanitizeValue(value: unknown, seen: WeakSet<object>): unknown {
  if (Array.isArray(value)) {
    return value.map((item) => sanitizeValue(item, seen));
  }

  if (value && typeof value === 'object') {
    if (seen.has(value)) {
      return '[Circular]';
    }

    seen.add(value);

    const source = value as JsonLike;
    const sanitized: JsonLike = {};

    for (const [key, currentValue] of Object.entries(source)) {
      if (SENSITIVE_KEYS.has(key)) {
        const sizeKb =
          typeof currentValue === 'string'
            ? estimateBase64Kilobytes(currentValue)
            : 0;
        sanitized[key] = key === 'imageData'
          ? `<omitted, ${sizeKb} KB>`
          : '<omitted>';
        continue;
      }

      sanitized[key] = sanitizeValue(currentValue, seen);
    }

    seen.delete(value);
    return sanitized;
  }

  return value;
}

export function sanitizeLogBody<T>(value: T): T {
  return sanitizeValue(value, new WeakSet<object>()) as T;
}
