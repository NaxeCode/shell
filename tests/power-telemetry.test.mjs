// Contract checks for the shared pp-status adapter; no hardware or subprocesses.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const code = readFileSync(new URL('../services/PowerTelemetry.js', import.meta.url), 'utf8').replace('.pragma library', '');
const context = vm.createContext({});
vm.runInContext(code, context);
for (const unknown of [null, undefined, NaN, Infinity, '0']) assert.equal(context.reading(unknown, ' W'), '—');
assert.equal(context.reading(0, ' W'), '0 W');
assert.equal(context.reading(-10, ' mV'), '-10 mV');
assert.equal(context.range([121, 172], 'W'), '121–172 W');
for (const invalid of [null, [null, null], [3, 2], [1], ['1', 2]]) assert.equal(context.range(invalid, 'W'), '—');
assert.equal(context.age(null, 1000), null);
assert.equal(context.age(100, 105_000), 5);
assert.equal(context.ageLabel(301), '5m ago');
const sample = {schema_version:2, sampled_at:'2026-09-30T00:00:00Z',cpu:{pkg_w:null},gpu:{power_w:0},heat:{},room:null,profile:{issues:[]},fans:[],warnings:[]};
assert.equal(context.validSnapshot(sample), true);
for (const mutation of [{schema_version:1}, {sampled_at:'bad'}, {cpu:null}, {room:[]}, {warnings:{}}, {profile:{}}])
    assert.equal(context.validSnapshot({...sample, ...mutation}), false);
console.log('Power telemetry contract checks passed.');
