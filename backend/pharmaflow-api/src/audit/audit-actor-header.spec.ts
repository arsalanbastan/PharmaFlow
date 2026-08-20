import { decodeActorDisplayNameHeader } from './audit-actor-header';

describe('decodeActorDisplayNameHeader', () => {
  it('decodes a UTF-8 Base64 Persian actor name', () => {
    const actor = 'ارسلان';

    const encoded = `utf8b64:${Buffer.from(actor, 'utf8').toString('base64')}`;

    expect(decodeActorDisplayNameHeader(encoded)).toBe(actor);
  });

  it('keeps backward compatibility with plain ASCII actor names', () => {
    expect(decodeActorDisplayNameHeader('  Arsalan  ')).toBe('Arsalan');
  });

  it('rejects malformed encoded actor metadata without throwing', () => {
    expect(
      decodeActorDisplayNameHeader('utf8b64:not valid base64!'),
    ).toBeUndefined();
  });

  it('returns undefined for empty actor metadata', () => {
    expect(decodeActorDisplayNameHeader('   ')).toBeUndefined();
    expect(decodeActorDisplayNameHeader(undefined)).toBeUndefined();
  });
});
