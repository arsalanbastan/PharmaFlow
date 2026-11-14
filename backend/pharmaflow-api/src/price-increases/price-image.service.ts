import {
  BadRequestException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';

@Injectable()
export class PriceImageService {
  extractText(text: string) {
    const normalized = text.replace(/[۰-۹٠-٩]/g, (digit) =>
      String('۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩'.indexOf(digit) % 10),
    );
    const lines = normalized.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
    const source = lines.map((line) => /^افزایش قیمت محصولات (.+?) از /.exec(line)?.[1]).find(Boolean);
    if (lines.length) {
      const rows = lines.flatMap((line) => {
        const match = /^(.+?)\s+([0-9]+(?:[.,٬][0-9]{3})*)\s*(ریال|تومان)(?:\s*\(\s*[0-9]+\s*[%٪]\s*افزایش\s*\))?$/.exec(line);
        return match ? [{
          name: match[1], price: match[2].replace(/[.,٬]/g, ''),
          unit: match[3] === 'ریال' ? 'RIAL' : 'TOMAN', note: null,
        }] : [];
      });
      const priceLines = lines.filter((line) => /ریال|تومان/.test(line));
      if (rows.length && rows.length === priceLines.length &&
          (rows.length === lines.length || (source && /قیمت[^\n]*مصرف\s*کننده/.test(normalized)))) {
        return this.prepareNotice({ rows, source: source ?? null, effectiveDate: null });
      }
    }
    throw new BadRequestException(
      'قالب متن شناسایی نشد. هر قلم را در یک خط با نام، مبلغ و واحد وارد کنید یا از ثبت دستی استفاده کنید.',
    );
  }

  private prepareNotice(result: unknown) {
    const rows = (result as { rows?: unknown })?.rows;
    if (!Array.isArray(rows)) {
      throw new BadRequestException('تصویر را به بخش‌های حداکثر ۱۰۰ ردیفی تقسیم کنید.');
    }
    const notice = result as { source?: unknown; effectiveDate?: unknown };
    if (rows.some((row) => !row || typeof row !== 'object' ||
      ![row.name, row.price, row.note].every((value) => value === null || typeof value === 'string') ||
      !['RIAL', 'TOMAN', 'UNKNOWN'].includes(row.unit))) {
      throw new ServiceUnavailableException('پاسخ استخراج اطلاعیه معتبر نیست.');
    }
    const unique = new Map<string, (typeof rows)[number]>();
    for (const row of rows) {
      const key = JSON.stringify([row.name?.trim(), row.price, row.unit]);
      if (!unique.has(key)) unique.set(key, row);
    }
    if (unique.size > 100) {
      throw new BadRequestException('اطلاعیه را به بخش‌های حداکثر ۱۰۰ ردیفی تقسیم کنید.');
    }
    const prices = new Map<string, Set<string>>();
    for (const row of unique.values()) {
      if (!row.name || !row.price) continue;
      const name = row.name.trim();
      const values = prices.get(name) ?? new Set<string>();
      values.add(`${row.price}:${row.unit}`);
      prices.set(name, values);
    }
    return {
      rows: [...unique.values()].map((row) => ({
        ...row,
        conflict: (prices.get(row.name?.trim())?.size ?? 0) > 1,
      })),
      source: notice.source,
      effectiveDate: notice.effectiveDate,
    };
  }
}
