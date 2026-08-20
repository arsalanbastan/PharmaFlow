import {
  isOrderTextSimilar,
  normalizeOrderSearchText,
  scoreOrderTextSimilarity,
} from './order-similarity';

describe('order text similarity', () => {
  it('normalizes Persian and Arabic character variants and digits', () => {
    expect(normalizeOrderSearchText('  آتورواستاتين ۲۰  ')).toBe(
      'اتورواستاتین 20',
    );

    expect(normalizeOrderSearchText('شئ‌كد')).toBe('شی کد');
  });

  it('matches text at the beginning, middle, or end', () => {
    expect(isOrderTextSimilar('اتورواستاتین', 'اتورواستاتین 20')).toBe(true);
    expect(isOrderTextSimilar('اتورواستاتین', 'قرص آتورواستاتین 20')).toBe(
      true,
    );
    expect(isOrderTextSimilar('اتورواستاتین', 'قرص 20 اتورواستاتین')).toBe(
      true,
    );
  });

  it('tolerates common transposition and missing-letter typos', () => {
    expect(isOrderTextSimilar('اتورواستاتین', 'اتروواستاتین')).toBe(true);
    expect(isOrderTextSimilar('اتورواستاتین', 'اترواستاتین')).toBe(true);
  });

  it('keeps unrelated orders out of the suggestions', () => {
    expect(isOrderTextSimilar('اتورواستاتین', 'شامپو فولیکا')).toBe(false);
    expect(isOrderTextSimilar('اتورواستاتین', 'روزوواستاتین')).toBe(false);
    expect(
      scoreOrderTextSimilarity('اتورواستاتین', 'شامپو فولیکا'),
    ).toBeLessThan(0.68);
  });
});
