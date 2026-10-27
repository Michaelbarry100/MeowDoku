// Independent exhaustive solver/data checks. No Godot engine code is reused.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
let checks = 0;
function check(condition, message) {
  assert.ok(condition, message);
  checks++;
  console.log('PASS: ' + message);
}
function validateLevel(level, label, expectedCount = 1) {
const n = level.size;
check(Number.isInteger(n) && n >= 1 && level.regions.length === n && level.regions.every(r => r.length === n), `${label}: square NxN board`);
const ids = new Set(level.regions.flat());
check(ids.size === n && [...ids].every(id => Number.isInteger(id) && id >= 0 && id < n), `${label}: exactly N valid region IDs`);
for (const id of ids) {
  const cells = [];
  for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) if (level.regions[r][c] === id) cells.push(`${r},${c}`);
  const visited = new Set([cells[0]]), queue = [cells[0]];
  while (queue.length) {
    const [r,c] = queue.shift().split(',').map(Number);
    for (const [dr,dc] of [[0,1],[0,-1],[1,0],[-1,0]]) {
      const key = `${r+dr},${c+dc}`;
      if (cells.includes(key) && !visited.has(key)) { visited.add(key); queue.push(key); }
    }
  }
  check(visited.size === cells.length, `Region ${id} is orthogonally connected`);
}
const solutions = [];
function solve(columns = [], regions = new Set()) {
  const r = columns.length;
  if (r === n) { solutions.push(columns); return; }
  for (let c = 0; c < n; c++) {
    const id = level.regions[r][c];
    if (columns.includes(c) || regions.has(id) || (r && Math.abs(columns[r-1] - c) <= 1)) continue;
    solve([...columns,c], new Set([...regions,id]));
  }
}
solve();
check(solutions.length === expectedCount, `${label}: exhaustive independent solution count is ${expectedCount}`);
if (level.solution) check(solutions.some(s => JSON.stringify(s) === JSON.stringify(level.solution)), `${label}: stored solution is legal`);
}
for (const name of fs.readdirSync(path.join(root, 'data')).filter(n => n.endsWith('.json'))) {
  validateLevel(JSON.parse(fs.readFileSync(path.join(root, 'data', name), 'utf8')), name);
}
const manifest = JSON.parse(fs.readFileSync(path.join(root, 'data/catalog/collection.json'), 'utf8'));
check(manifest.version === 1 && manifest.levels.length === 150 && manifest.target_count === 150, 'Campaign contains exactly 150 real puzzles');
const legacy = JSON.parse(fs.readFileSync(path.join(root, 'tests/fixtures/legacy_campaign_v1.json'), 'utf8'));
function signature(grid) {
  const mapping = new Map();
  return JSON.stringify(grid.flat().map(id => {if (!mapping.has(id)) mapping.set(id,mapping.size); return mapping.get(id);}));
}
function symmetry(grid) {
  const variants = [], n = grid.length;
  for (let turn = 0; turn < 4; turn++) {
    variants.push(signature(grid), signature(grid.map(row => [...row].reverse())));
    grid = Array.from({length:n}, (_,r) => Array.from({length:n}, (_,c) => grid[n-1-c][r]));
  }
  return variants.sort()[0];
}
// Independent implementation of the documented forward-search effort metric.
function difficulty(level) {
  const n=level.size, areas=Array(n).fill(0); level.regions.flat().forEach(id=>areas[id]++);
  let nodes=0;
  function visit(a=[], cols=new Set(), regs=new Set()) {
    nodes++; const r=a.length; if(r===n) return;
    const available=new Set();
    for(let f=r;f<n;f++) {
      let found=false;
      for(let c=0;c<n;c++) {
        const id=level.regions[f][c];
        if(cols.has(c)||regs.has(id)||(f===r&&r>0&&Math.abs(a[r-1]-c)<=1)) continue;
        found=true; available.add(id);
      }
      if(!found) return;
    }
    if(available.size!==n-regs.size) return;
    for(let c=0;c<n;c++) {
      const id=level.regions[r][c];
      if(cols.has(c)||regs.has(id)||(r>0&&Math.abs(a[r-1]-c)<=1)) continue;
      visit([...a,c],new Set([...cols,c]),new Set([...regs,id]));
    }
  }
  visit(); const singletons=areas.filter(x=>x===1).length;
  return {score:(n-singletons)*100+nodes, singletons, solver_nodes:nodes};
}
const groups = new Map(), signatures = new Set(), levelIds = new Set(), titles = new Set();
const puzzles=[]; let previousScore=-Infinity;
for (const [index,entry] of manifest.levels.entries()) {
  const puzzle = JSON.parse(fs.readFileSync(path.join(root, entry.path.replace('res://', '')), 'utf8'));
  puzzles.push(puzzle);
  validateLevel(puzzle, puzzle.id);
  check(puzzle.size===5 && Array.isArray(puzzle.solution) && puzzle.order===index+1, 'Real playable board and contiguous order: '+puzzle.id);
  check(!levelIds.has(puzzle.id), 'Unique campaign ID: ' + puzzle.id);
  check(!puzzle.id.startsWith('daily_'), 'Daily remains outside campaign count');
  levelIds.add(puzzle.id);
  const key=symmetry(puzzle.regions);
  check(!signatures.has(key), 'Unique region geometry including rotations/reflections: ' + puzzle.id);
  signatures.add(key);
  check(typeof puzzle.title==='string'&&!titles.has(puzzle.title), 'Unique real title: '+puzzle.id); titles.add(puzzle.title);
  groups.set(puzzle.difficulty, (groups.get(puzzle.difficulty) || 0) + 1);
  if(index>=2) {
    const measured=difficulty(puzzle);
    check(JSON.stringify(measured)===JSON.stringify({score:puzzle.curation.score,singletons:puzzle.curation.singletons,solver_nodes:puzzle.curation.solver_nodes}), 'Verified difficulty metrics: '+puzzle.id);
    check(measured.score>=previousScore, 'Nondecreasing difficulty after two introductory boards'); previousScore=measured.score;
    const group=measured.score<411?'Easy':measured.score<417?'Medium':measured.score<424?'Hard':'Expert';
    check(puzzle.difficulty===group,'Difficulty group matches effort band');
  }
}
check(puzzles[0].id==='easy_01' && puzzles[1].id==='easy_02', 'Original two introductory boards remain first');
for (const [group,count] of Object.entries({Easy:38,Medium:38,Hard:37,Expert:37})) check(groups.get(group)===count && manifest.difficulty_counts[group]===count, 'Declared curated levels: '+group);
check(fs.readdirSync(path.join(root,'data/levels')).filter(f=>f.endsWith('.json')).length===150, 'Exactly 150 definitions, no orphan or placeholder files');
for(const old of legacy.levels) {
  const current=puzzles.find(p=>p.id===old.id); const clean=p=>{const c={...p};delete c.order;return c;};
  check(current && JSON.stringify(clean(current))===JSON.stringify(clean(old)), 'Original board/ID/solution/metadata preserved: '+old.id);
}
check(manifest.daily_seed===legacy.daily_seed && JSON.stringify(manifest.daily_pool)===JSON.stringify(legacy.levels.map(p=>p.id)), 'Original daily seed and source pool remain stable');
for (const [name, expected] of [['unique_four',1], ['multiple_four',2], ['unsolvable_two',0], ['single',1]]) {
  validateLevel(JSON.parse(fs.readFileSync(path.join(root, 'tests/fixtures', name + '.json'), 'utf8')), 'fixture ' + name, expected);
}
function files(dir) {
  return fs.readdirSync(dir, {withFileTypes:true}).flatMap(e => e.name.startsWith('.') ? [] : e.isDirectory() ? files(path.join(dir,e.name)) : [path.join(dir,e.name)]);
}
for (const file of files(root).filter(f => /\.(gd|tscn|tres|godot)$/.test(f))) {
  // Actual static dependencies, excluding output paths/comments and deliberate
  // missing-file test inputs. Dynamic fixture paths are checked in Godot.
  const content = fs.readFileSync(file,'utf8').replace(/^\s*#.*$/gm, '');
  const references = [
    ...content.matchAll(/(?:preload|load|FileAccess\.get_file_as_string)\("res:\/\/([^"\s]+)"/g),
    ...content.matchAll(/(?:path|run\/main_scene|config\/icon)="res:\/\/([^"\s]+)"/g),
    ...content.matchAll(/const FIRST_PUZZLE := "res:\/\/([^"\s]+)"/g),
  ];
  for (const [,ref] of references) check(fs.existsSync(path.join(root,ref)), `${path.relative(root,file)} static dependency exists: ${ref}`);
}
console.log(`RESULT: ${checks} checks passed. Godot execution requires separate engine tests.`);
