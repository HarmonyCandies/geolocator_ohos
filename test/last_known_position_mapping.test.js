'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  completeLastKnownPosition,
  mapLastKnownPosition,
} = require('./last_known_position_mapping.js');

function createMethodResult() {
  let completed = false;
  const calls = [];
  const failIfAlreadyCompleted = () => {
    if (completed) {
      throw new Error('MethodResult completed more than once');
    }
    completed = true;
  };
  return {
    success(value) {
      failIfAlreadyCompleted();
      calls.push({ type: 'success', value });
    },
    error(code, message, details) {
      failIfAlreadyCompleted();
      calls.push({ type: 'error', code, message, details });
    },
    get completed() {
      return completed;
    },
    get lastCall() {
      return calls[calls.length - 1];
    },
    calls,
  };
}

const sampleLocation = {
  latitude: 31.23,
  longitude: 121.47,
  altitude: 10,
  accuracy: 5,
  timeStamp: 1700000000000,
};

describe('last-known MethodResult mapping', () => {
  it('keeps the existing success payload for a cached location', () => {
    const result = createMethodResult();
    completeLastKnownPosition(result, sampleLocation, undefined);
    assert.equal(result.completed, true);
    assert.deepEqual(result.lastCall, {
      type: 'success',
      value: JSON.stringify(sampleLocation),
    });
  });

  it('completes with success(null) when there is no last location', () => {
    const result = createMethodResult();
    completeLastKnownPosition(result, undefined, undefined);
    assert.equal(result.completed, true);
    assert.deepEqual(result.lastCall, { type: 'success', value: null });
  });

  it('completes with success(null) when getLastLocation throws 3301100', async () => {
    const result = createMethodResult();
    const thrown = Object.assign(new Error('The location is not obtained'), {
      code: 3301100,
    });

    await Promise.race([
      (async () => {
        try {
          throw thrown;
        } catch (error) {
          completeLastKnownPosition(result, undefined, error);
        }
      })(),
      new Promise((_, reject) => {
        setTimeout(() => reject(new Error('MethodResult hung')), 1000);
      }),
    ]);

    assert.equal(result.completed, true, 'MethodResult must complete; must not hang');
    assert.deepEqual(result.lastCall, { type: 'success', value: null });
  });

  it('completes with success(null) for other empty-last-location BusinessErrors', () => {
    for (const code of [3301200, 3301000, 801]) {
      const result = createMethodResult();
      completeLastKnownPosition(result, undefined, {
        code,
        message: `BusinessError ${code}`,
      });
      assert.equal(result.completed, true, `code ${code} must complete`);
      assert.equal(result.lastCall.type, 'success', `code ${code} must not hang or leave result open`);
      assert.equal(result.lastCall.value, null);
    }
  });

  it('completes with result.error for unexpected throws (still never hangs)', async () => {
    const result = createMethodResult();
    const thrown = Object.assign(new Error('permission verification failed'), {
      code: 201,
    });

    await Promise.race([
      Promise.resolve().then(() => {
        completeLastKnownPosition(result, undefined, thrown);
      }),
      new Promise((_, reject) => {
        setTimeout(() => reject(new Error('MethodResult hung')), 1000);
      }),
    ]);

    assert.equal(result.completed, true);
    assert.equal(result.lastCall.type, 'error');
    assert.equal(result.lastCall.code, '201');
  });

  it('mapLastKnownPosition never returns an incomplete mapping', () => {
    const cases = [
      [sampleLocation, undefined],
      [undefined, undefined],
      [null, { code: 3301100, message: 'no last location' }],
      [undefined, { code: 3301100 }],
      [undefined, { code: 201, message: 'denied' }],
    ];
    for (const [location, error] of cases) {
      const mapped = mapLastKnownPosition(location, error);
      assert.ok(mapped.kind === 'success' || mapped.kind === 'error');
      if (mapped.kind === 'success') {
        assert.ok(mapped.value === null || typeof mapped.value === 'string');
      }
    }
  });
});
