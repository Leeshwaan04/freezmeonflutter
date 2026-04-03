import { geohashForCoords, getGeohashRanges, kmBetween } from '../../src/services/geo';

describe('Geo Service — Unit Tests', () => {

  // ── geohashForCoords ──────────────────────────────────────────────────────

  describe('geohashForCoords', () => {
    it('returns a string for valid coords', () => {
      const hash = geohashForCoords(19.076, 72.877);
      expect(typeof hash).toBe('string');
      expect(hash.length).toBeGreaterThan(0);
    });

    it('Mumbai coords produce known geohash prefix', () => {
      const hash = geohashForCoords(19.076, 72.877);
      expect(hash.startsWith('te')).toBe(true);
    });

    it('Delhi coords produce known geohash prefix', () => {
      const hash = geohashForCoords(28.6139, 77.2090);
      expect(hash.startsWith('tt')).toBe(true);
    });

    it('same coords always produce same hash', () => {
      const h1 = geohashForCoords(19.076, 72.877);
      const h2 = geohashForCoords(19.076, 72.877);
      expect(h1).toBe(h2);
    });

    it('nearby coords produce hashes with same prefix', () => {
      const h1 = geohashForCoords(19.076,  72.877);
      const h2 = geohashForCoords(19.077,  72.878);
      // At precision 9, first 5-6 chars should match for ~100m distance
      expect(h1.substring(0, 5)).toBe(h2.substring(0, 5));
    });

    it('very different coords produce different hashes', () => {
      const mumbai = geohashForCoords(19.076, 72.877);
      const london = geohashForCoords(51.507, -0.127);
      expect(mumbai).not.toBe(london);
      expect(mumbai.substring(0, 2)).not.toBe(london.substring(0, 2));
    });

    it('handles equator / prime meridian (0,0)', () => {
      const hash = geohashForCoords(0, 0);
      expect(hash).toBeTruthy();
    });

    it('handles extreme coords (poles)', () => {
      const north = geohashForCoords(89.9, 0);
      const south = geohashForCoords(-89.9, 0);
      expect(north).toBeTruthy();
      expect(south).toBeTruthy();
      expect(north).not.toBe(south);
    });
  });

  // ── getGeohashRanges ──────────────────────────────────────────────────────

  describe('getGeohashRanges', () => {
    it('returns an array of [start, end] tuples', () => {
      const ranges = getGeohashRanges(19.076, 72.877, 10);
      expect(Array.isArray(ranges)).toBe(true);
      expect(ranges.length).toBeGreaterThan(0);
      ranges.forEach(([start, end]) => {
        expect(typeof start).toBe('string');
        expect(typeof end).toBe('string');
        expect(start <= end).toBe(true);
      });
    });

    it('smaller radius produces fewer or equal ranges', () => {
      const small = getGeohashRanges(19.076, 72.877, 1);
      const large = getGeohashRanges(19.076, 72.877, 100);
      // Large radius should cover more cells
      expect(large.length).toBeGreaterThanOrEqual(small.length);
    });
  });

  // ── kmBetween ─────────────────────────────────────────────────────────────

  describe('kmBetween', () => {
    it('same point is 0 km', () => {
      const dist = kmBetween(19.076, 72.877, 19.076, 72.877);
      expect(dist).toBeCloseTo(0, 1);
    });

    it('Mumbai to Delhi is ~1150 km', () => {
      const dist = kmBetween(19.076, 72.877, 28.6139, 77.209);
      expect(dist).toBeGreaterThan(1100);
      expect(dist).toBeLessThan(1200);
    });

    it('is symmetric (A→B == B→A)', () => {
      const ab = kmBetween(19.076, 72.877, 28.6139, 77.209);
      const ba = kmBetween(28.6139, 77.209, 19.076, 72.877);
      expect(Math.abs(ab - ba)).toBeLessThan(0.01);
    });

    it('very close points return small value', () => {
      const dist = kmBetween(19.076, 72.877, 19.077, 72.878);
      expect(dist).toBeLessThan(0.2);
    });
  });
});
