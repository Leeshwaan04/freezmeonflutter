"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.distanceBetween = exports.geohashQueryBounds = exports.geohashForLocation = void 0;
exports.geohashForCoords = geohashForCoords;
exports.getGeohashRanges = getGeohashRanges;
exports.kmBetween = kmBetween;
// Geohash utilities — mirrors geofire-common used in original Cloud Functions
const geofire_common_1 = require("geofire-common");
Object.defineProperty(exports, "geohashForLocation", { enumerable: true, get: function () { return geofire_common_1.geohashForLocation; } });
Object.defineProperty(exports, "geohashQueryBounds", { enumerable: true, get: function () { return geofire_common_1.geohashQueryBounds; } });
Object.defineProperty(exports, "distanceBetween", { enumerable: true, get: function () { return geofire_common_1.distanceBetween; } });
function geohashForCoords(lat, lng, precision = 9) {
    return (0, geofire_common_1.geohashForLocation)([lat, lng], precision);
}
function getGeohashRanges(lat, lng, radiusKm) {
    const bounds = (0, geofire_common_1.geohashQueryBounds)([lat, lng], radiusKm * 1000);
    return bounds.map((b) => [b[0], b[1]]);
}
function kmBetween(lat1, lng1, lat2, lng2) {
    return (0, geofire_common_1.distanceBetween)([lat1, lng1], [lat2, lng2]);
}
//# sourceMappingURL=geo.js.map