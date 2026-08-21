'use strict';

/**
 * Last-known MethodResult mapping used by GeolocatorOhosPlugin.
 * Keep in sync with ohos/src/main/ets/components/plugin/GeolocatorOhosPlugin.ets
 *
 * Official geolocator / this plugin's Dart side:
 * getLastKnownPosition returns null when no last fix is available.
 * OpenHarmony getLastLocation throws BusinessError instead of returning empty:
 *   3301100 no cached location / location switch off
 *   3301200 failed to obtain location
 *   3301000 location service unavailable
 *   801     capability not supported
 */

const NO_LAST_LOCATION_CODES = new Set([
  3301100,
  3301200,
  3301000,
  801,
]);

function errorCode(error) {
  if (error == null) {
    return undefined;
  }
  if (typeof error === 'number') {
    return error;
  }
  if (typeof error === 'object' && error.code != null) {
    return Number(error.code);
  }
  return undefined;
}

function isUnknownLastLocationError(error) {
  if (error == null) {
    return true;
  }
  const code = errorCode(error);
  return code != null && NO_LAST_LOCATION_CODES.has(code);
}

function mapLastKnownPosition(location, error) {
  if (location != null && error == null) {
    return { kind: 'success', value: JSON.stringify(location) };
  }
  if (error == null || isUnknownLastLocationError(error)) {
    return { kind: 'success', value: null };
  }
  return {
    kind: 'error',
    code: String(error.code ?? ''),
    message: error.message || 'getLastKnownPosition failed',
    details: '',
  };
}

function completeLastKnownPosition(result, location, error) {
  const mapped = mapLastKnownPosition(location, error);
  if (mapped.kind === 'success') {
    result.success(mapped.value);
  } else {
    result.error(mapped.code, mapped.message, mapped.details);
  }
  return mapped;
}

module.exports = {
  NO_LAST_LOCATION_CODES,
  isUnknownLastLocationError,
  mapLastKnownPosition,
  completeLastKnownPosition,
};
