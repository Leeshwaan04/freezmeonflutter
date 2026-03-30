// Geohash utilities — mirrors geofire-common used in original Cloud Functions
import { geohashForLocation, geohashQueryBounds, distanceBetween } from 'geofire-common';

export { geohashForLocation, geohashQueryBounds, distanceBetween };

export function geohashForCoords(lat: number, lng: number, precision = 9): string {
  return geohashForLocation([lat, lng], precision);
}

export function getGeohashRanges(
  lat: number,
  lng: number,
  radiusKm: number
): Array<[string, string]> {
  const bounds = geohashQueryBounds([lat, lng], radiusKm * 1000);
  return bounds.map((b) => [b[0], b[1]] as [string, string]);
}

export function kmBetween(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number
): number {
  return distanceBetween([lat1, lng1], [lat2, lng2]);
}
