'use strict';

const assert = require('node:assert/strict');
const expectedABI = process.env.EXPECTED_NODE_ABI;
assert.match(expectedABI || '', /^(127|131|137)$/, 'expected tested Node ABI');
assert.equal(process.versions.modules, expectedABI, 'matching Node addon ABI');
const mbgl = require('../../platform/node');
assert.equal(typeof mbgl.Map, 'function');

const map = new mbgl.Map();
const watchdog = setTimeout(() => {
    console.error('Minimal render timed out');
    process.exit(1);
}, 30000);

map.load(JSON.stringify({
    version: 8,
    sources: {},
    layers: [{
        id: 'background',
        type: 'background',
        paint: {'background-color': '#e31a1c'}
    }]
}));
map.render({width: 64, height: 64}, (error, pixels) => {
    clearTimeout(watchdog);
    try {
        if (error) throw error;
        assert(Buffer.isBuffer(pixels), 'render returned a Buffer');
        assert.equal(pixels.length, 64 * 64 * 4, '64x64 RGBA image');
        console.log(`Node ${process.version}, ABI ${process.versions.modules}: rendered ${pixels.length} bytes`);
    } finally {
        map.release();
    }
});
