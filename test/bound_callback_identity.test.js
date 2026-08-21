'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
  createStoredBoundCallback,
  subscribeWithStoredCallback,
  unsubscribeWithStoredCallback,
} = require('./bound_callback_identity.js');

function createMockManager() {
  const ons = [];
  const offs = [];
  return {
    on(type, requestOrCallback, maybeCallback) {
      const callback = typeof requestOrCallback === 'function' ? requestOrCallback : maybeCallback;
      ons.push({ type, callback });
    },
    off(type, callback) {
      offs.push({ type, callback });
    },
    ons,
    offs,
  };
}

describe('stream on/off callback identity', () => {
  it('fresh .bind(this) on on() and off() are different references (the leak)', () => {
    const handler = {
      locationChange() {},
    };
    const onCallback = handler.locationChange.bind(handler);
    const offCallback = handler.locationChange.bind(handler);
    assert.notStrictEqual(onCallback, offCallback);
  });

  it('stored bind: on-callback === off-callback for locationChange', () => {
    const manager = createMockManager();
    const handler = {
      locationChange() {},
    };
    const stored = createStoredBoundCallback(handler.locationChange, handler);

    const onCallback = subscribeWithStoredCallback(
      manager,
      'locationChange',
      { priority: 0x203 },
      stored,
    );
    const offCallback = unsubscribeWithStoredCallback(manager, 'locationChange', stored);

    assert.ok(onCallback, 'subscribe must register a callback');
    assert.ok(offCallback, 'unsubscribe must pass a callback');
    assert.strictEqual(onCallback, offCallback);
    assert.strictEqual(manager.ons[0].callback, manager.offs[0].callback);
    assert.strictEqual(manager.ons[0].type, 'locationChange');
    assert.strictEqual(manager.offs[0].type, 'locationChange');
  });

  it('stored bind: on-callback === off-callback for locationEnabledChange', () => {
    const manager = createMockManager();
    const handler = {
      locationEnabledChange() {},
    };
    const stored = createStoredBoundCallback(handler.locationEnabledChange, handler);

    const onCallback = subscribeWithStoredCallback(
      manager,
      'locationEnabledChange',
      undefined,
      stored,
    );
    const offCallback = unsubscribeWithStoredCallback(
      manager,
      'locationEnabledChange',
      stored,
    );

    assert.strictEqual(onCallback, offCallback);
    assert.strictEqual(manager.ons[0].callback, manager.offs[0].callback);
  });

  it('resubscribe reuses the same stored callback', () => {
    const manager = createMockManager();
    const handler = { locationChange() {} };
    const stored = createStoredBoundCallback(handler.locationChange, handler);

    subscribeWithStoredCallback(manager, 'locationChange', {}, stored);
    unsubscribeWithStoredCallback(manager, 'locationChange', stored);
    subscribeWithStoredCallback(manager, 'locationChange', {}, stored);
    unsubscribeWithStoredCallback(manager, 'locationChange', stored);

    assert.strictEqual(manager.ons[0].callback, manager.offs[0].callback);
    assert.strictEqual(manager.ons[0].callback, manager.ons[1].callback);
    assert.strictEqual(manager.ons[1].callback, manager.offs[1].callback);
  });

  it('unsubscribe before subscribe does not invent a new off() handle', () => {
    const manager = createMockManager();
    const handler = { locationChange() {} };
    const stored = createStoredBoundCallback(handler.locationChange, handler);

    const offCallback = unsubscribeWithStoredCallback(manager, 'locationChange', stored);
    assert.equal(offCallback, null);
    assert.equal(manager.offs.length, 0);
  });

  it('ETS handlers store one bind and pass that field to on() and off()', () => {
    const files = [
      'ohos/src/main/ets/components/plugin/handlers/stream_handler/PositionStreamHandler.ets',
      'ohos/src/main/ets/components/plugin/handlers/stream_handler/ServiceStatusStreamHandler.ets',
    ];
    for (const rel of files) {
      const src = fs.readFileSync(path.join(__dirname, '..', rel), 'utf8');
      assert.match(src, /Callback\s*=\s*this\.\w+\.bind\(this\)/, `${rel} must bind once into a field`);
      assert.match(src, /\.on\([^;]*Callback\)/, `${rel} on() must use the stored field`);
      assert.match(src, /\.off\([^;]*Callback\)/, `${rel} off() must use the stored field`);
      assert.doesNotMatch(
        src,
        /\.off\([^)]*\.bind\(this\)/,
        `${rel} off() must not create a new .bind(this)`,
      );
    }
  });
});
