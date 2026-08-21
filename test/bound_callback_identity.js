'use strict';

/**
 * HarmonyOS geoLocationManager.on/off require the same function reference.
 * Each `.bind(this)` creates a new function, so off() never matches on()
 * unless the bound callback is stored once and reused.
 *
 * Keep in sync with:
 *   ohos/src/main/ets/components/plugin/handlers/stream_handler/PositionStreamHandler.ets
 *   ohos/src/main/ets/components/plugin/handlers/stream_handler/ServiceStatusStreamHandler.ets
 */

function createStoredBoundCallback(method, context) {
  let stored = null;
  return {
    getForSubscribe() {
      if (stored == null) {
        stored = method.bind(context);
      }
      return stored;
    },
    getForUnsubscribe() {
      return stored;
    },
  };
}

function subscribeWithStoredCallback(manager, type, requestInfo, stored) {
  const callback = stored.getForSubscribe();
  if (arguments.length > 3 && requestInfo !== undefined && typeof requestInfo !== 'function') {
    manager.on(type, requestInfo, callback);
  } else {
    manager.on(type, callback);
  }
  return callback;
}

function unsubscribeWithStoredCallback(manager, type, stored) {
  const callback = stored.getForUnsubscribe();
  if (callback != null) {
    manager.off(type, callback);
  }
  return callback;
}

module.exports = {
  createStoredBoundCallback,
  subscribeWithStoredCallback,
  unsubscribeWithStoredCallback,
};
