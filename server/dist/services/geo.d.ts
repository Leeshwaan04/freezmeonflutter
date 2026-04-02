import { geohashForLocation, geohashQueryBounds, distanceBetween } from 'geofire-common';
export { geohashForLocation, geohashQueryBounds, distanceBetween };
export declare function geohashForCoords(lat: number, lng: number, precision?: number): string;
export declare function getGeohashRanges(lat: number, lng: number, radiusKm: number): Array<[string, string]>;
export declare function kmBetween(lat1: number, lng1: number, lat2: number, lng2: number): number;
//# sourceMappingURL=geo.d.ts.map