const DIGIT_MAP: Record<string, string> = {
  '۰': '0',
  '۱': '1',
  '۲': '2',
  '۳': '3',
  '۴': '4',
  '۵': '5',
  '۶': '6',
  '۷': '7',
  '۸': '8',
  '۹': '9',
  '٠': '0',
  '١': '1',
  '٢': '2',
  '٣': '3',
  '٤': '4',
  '٥': '5',
  '٦': '6',
  '٧': '7',
  '٨': '8',
  '٩': '9',
};

const MIN_FUZZY_QUERY_LENGTH = 5;
const MIN_FUZZY_SCORE = 0.78;

export function normalizeOrderSearchText(raw: string): string {
  return raw
    .normalize('NFKC')
    .trim()
    .toLowerCase()
    .replace(/[آأإٱ]/g, 'ا')
    .replace(/[ئيى]/g, 'ی')
    .replace(/ك/g, 'ک')
    .replace(/ؤ/g, 'و')
    .replace(/[ةۀ]/g, 'ه')
    .replace(/[ً-ٰٟۖ-ۭـ]/g, '')
    .replace(/[۰-۹٠-٩]/g, (digit) => DIGIT_MAP[digit] ?? digit)
    .replace(/[​-‏‪-‮⁠﻿]/g, ' ')
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

export function scoreOrderTextSimilarity(
  queryText: string,
  candidateText: string,
): number {
  const query = normalizeOrderSearchText(queryText);
  const candidate = normalizeOrderSearchText(candidateText);

  if (query.length === 0 || candidate.length === 0) {
    return 0;
  }

  if (query === candidate) {
    return 1;
  }

  const queryCompact = query.replace(/\s/g, '');
  const candidateCompact = candidate.replace(/\s/g, '');

  if (candidate.includes(query) || candidateCompact.includes(queryCompact)) {
    return 0.94 + 0.06 * (queryCompact.length / candidateCompact.length);
  }

  if (query.includes(candidate) || queryCompact.includes(candidateCompact)) {
    return 0.88 + 0.1 * (candidateCompact.length / queryCompact.length);
  }

  if (queryCompact.length < MIN_FUZZY_QUERY_LENGTH) {
    return 0;
  }

  const editScore = normalizedDamerauSimilarity(queryCompact, candidateCompact);
  const bigramScore = diceCoefficient(queryCompact, candidateCompact);
  const tokenScore = weightedTokenSimilarity(query, candidate);

  return Math.max(editScore, bigramScore, tokenScore);
}

export function isOrderTextSimilar(
  queryText: string,
  candidateText: string,
): boolean {
  const normalizedQuery = normalizeOrderSearchText(queryText);
  const compactQuery = normalizedQuery.replace(/\s/g, '');

  if (compactQuery.length < 2) {
    return false;
  }

  return (
    scoreOrderTextSimilarity(normalizedQuery, candidateText) >= MIN_FUZZY_SCORE
  );
}

function weightedTokenSimilarity(query: string, candidate: string): number {
  const queryTokens = query.split(' ').filter(Boolean);
  const candidateTokens = candidate.split(' ').filter(Boolean);

  const queryCoverage = tokenCoverage(queryTokens, candidateTokens);
  const candidateCoverage = tokenCoverage(candidateTokens, queryTokens);

  return queryCoverage * 0.75 + candidateCoverage * 0.25;
}

function tokenCoverage(sourceTokens: string[], targetTokens: string[]): number {
  let weightedScore = 0;
  let totalWeight = 0;

  for (const source of sourceTokens) {
    const weight = Math.max(2, source.length);
    let bestScore = 0;

    for (const target of targetTokens) {
      bestScore = Math.max(bestScore, tokenSimilarity(source, target));
    }

    weightedScore += bestScore * weight;
    totalWeight += weight;
  }

  return totalWeight === 0 ? 0 : weightedScore / totalWeight;
}

function tokenSimilarity(left: string, right: string): number {
  if (left === right) {
    return 1;
  }

  const shorterLength = Math.min(left.length, right.length);
  const longerLength = Math.max(left.length, right.length);

  if (shorterLength >= 2 && (left.includes(right) || right.includes(left))) {
    return 0.88 + 0.12 * (shorterLength / longerLength);
  }

  if (shorterLength < 3) {
    return 0;
  }

  return Math.max(
    normalizedDamerauSimilarity(left, right),
    diceCoefficient(left, right),
  );
}

function normalizedDamerauSimilarity(left: string, right: string): number {
  const longestLength = Math.max(left.length, right.length);

  if (longestLength === 0) {
    return 1;
  }

  return 1 - damerauLevenshteinDistance(left, right) / longestLength;
}

function damerauLevenshteinDistance(left: string, right: string): number {
  const rows = left.length + 1;
  const columns = right.length + 1;
  const matrix = Array.from({ length: rows }, () =>
    Array<number>(columns).fill(0),
  );

  for (let row = 0; row < rows; row += 1) {
    matrix[row][0] = row;
  }

  for (let column = 0; column < columns; column += 1) {
    matrix[0][column] = column;
  }

  for (let row = 1; row < rows; row += 1) {
    for (let column = 1; column < columns; column += 1) {
      const substitutionCost = left[row - 1] === right[column - 1] ? 0 : 1;

      matrix[row][column] = Math.min(
        matrix[row - 1][column] + 1,
        matrix[row][column - 1] + 1,
        matrix[row - 1][column - 1] + substitutionCost,
      );

      if (
        row > 1 &&
        column > 1 &&
        left[row - 1] === right[column - 2] &&
        left[row - 2] === right[column - 1]
      ) {
        matrix[row][column] = Math.min(
          matrix[row][column],
          matrix[row - 2][column - 2] + substitutionCost,
        );
      }
    }
  }

  return matrix[left.length][right.length];
}

function diceCoefficient(left: string, right: string): number {
  if (left === right) {
    return 1;
  }

  if (left.length < 2 || right.length < 2) {
    return 0;
  }

  const leftBigrams = bigramCounts(left);
  const rightBigrams = bigramCounts(right);
  let intersection = 0;

  for (const [bigram, leftCount] of leftBigrams) {
    intersection += Math.min(leftCount, rightBigrams.get(bigram) ?? 0);
  }

  return (2 * intersection) / (left.length + right.length - 2);
}

function bigramCounts(value: string): Map<string, number> {
  const counts = new Map<string, number>();

  for (let index = 0; index < value.length - 1; index += 1) {
    const bigram = value.slice(index, index + 2);
    counts.set(bigram, (counts.get(bigram) ?? 0) + 1);
  }

  return counts;
}
