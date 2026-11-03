const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

// Exercise the actual model helpers without requiring a running QML engine.
const source = readFileSync(join(__dirname, '..', 'Workspaces.qml'), 'utf8');
function helper(name) {
  const start = source.indexOf(`  function ${name}(`);
  assert.notEqual(start, -1);
  const body = source.indexOf('{', start);
  let depth = 1;
  let end = body + 1;
  while (depth && end < source.length) {
    if (source[end] === '{') depth++;
    if (source[end] === '}') depth--;
    end++;
  }
  return source.slice(start, end);
}
function model() {
  const root = { liveClients: [], clientsLoaded: true, showIcons: true, maxIcons: 0, iconFor: c => c.class };
  const context = vm.createContext({ root });
  for (const name of ['clientsFor', 'hasWindows', 'iconsFor']) {
    vm.runInContext(helper(name), context);
    root[name] = context[name];
  }
  return root;
}
const client = (address, workspaceId, cls = 'app', extra = {}) => ({
  address, workspace: { id: workspaceId }, class: cls,
  mapped: true, hidden: false, ...extra
});

test('closed windows disappear even if workspace.toplevels is stale', () => {
  const root = model();
  const workspace = { id: 1, toplevels: { values: [{}, {}] } };
  root.liveClients = [client('a', 1, 'chat'), client('b', 1, 'terminal')];
  assert.equal(root.iconsFor(workspace), 'chat terminal');
  root.liveClients = [client('a', 1, 'chat')];
  assert.equal(root.iconsFor(workspace), 'chat');
  root.liveClients = [];
  assert.equal(root.iconsFor(workspace), '');
  assert.equal(root.hasWindows(workspace), false);
});

test('moves update source, destination and scratchpad occupancy', () => {
  const root = model();
  root.liveClients = [client('a', 1)];
  assert.equal(root.hasWindows({ id: 1 }), true);
  root.liveClients = [client('a', 2)];
  assert.equal(root.hasWindows({ id: 1 }), false);
  assert.equal(root.hasWindows({ id: 2 }), true);
  root.liveClients = [client('a', -99)];
  assert.equal(root.hasWindows({ id: 2 }), false);
  assert.equal(root.hasWindows({ id: -99 }), true);
});

test('filters invalid and unmapped clients', () => {
  const root = model();
  root.liveClients = [null, {}, client('a', 1),
    client('b', 1, 'app', { mapped: false }),
    client('d', 2)];
  assert.equal(root.clientsFor({ id: 1 }).length, 1);
  assert.equal(root.hasWindows(null), false);
});

test('icon limits and disabled icons retain their behavior', () => {
  const root = model();
  root.liveClients = [client('a', 1, 'chat'), client('b', 1, 'terminal')];
  root.maxIcons = 1;
  assert.equal(root.iconsFor({ id: 1 }), 'chat +1');
  root.liveClients = [client('a', 1, 'new-title-icon')];
  assert.equal(root.iconsFor({ id: 1 }), 'new-title-icon');
  root.showIcons = false;
  assert.equal(root.iconsFor({ id: 1 }), '');
  assert.equal(root.hasWindows({ id: 1 }), true);
});

test('workspace.toplevels stands in until the first snapshot', () => {
  const root = model();
  root.clientsLoaded = false;
  const workspace = { id: 1, toplevels: { values: [{ class: 'chat' }] } };
  assert.equal(root.iconsFor(workspace), 'chat');
  assert.equal(root.hasWindows({ id: 2 }), false);
  root.clientsLoaded = true;
  assert.equal(root.iconsFor(workspace), '');
});

test('hidden group tabs keep their icons and occupancy', () => {
  const root = model();
  root.liveClients = [client('a', 1, 'chat'),
    client('b', 1, 'terminal', { hidden: true, grouped: ['a', 'b'] })];
  assert.equal(root.iconsFor({ id: 1 }), 'chat terminal');
  root.liveClients = [client('b', 1, 'terminal', { hidden: true })];
  assert.equal(root.hasWindows({ id: 1 }), true);
});

test('events during a running query schedule one follow-up', () => {
  let starts = 0;
  const root = { clientsPending: false };
  const clientsProc = { running: true };
  const clientsDebounce = { start() { starts++; } };
  const context = vm.createContext({ root, clientsProc, clientsDebounce });
  vm.runInContext(helper('refreshClients'), context);
  for (let i = 0; i < 100; i++) context.refreshClients();
  assert.equal(root.clientsPending, true);
  assert.equal(starts, 0);
  clientsProc.running = false;
  const proc = source.slice(source.indexOf('id: clientsProc'));
  const handler = proc.match(/onRunningChanged: \{([\s\S]*?)\n    \}/)[1];
  context.running = false;
  vm.runInContext(handler, context);
  assert.equal(root.clientsPending, false);
  assert.equal(starts, 1);
  context.refreshClients();
  assert.equal(clientsProc.running, true);
});
