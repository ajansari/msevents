#!/usr/bin/env node
// Checks the event data in index.html: it still parses, every entry is well formed,
// every city has map coordinates, and the list is in date order.
// Usage: node .github/scripts/validate-events.mjs [path/to/index.html] [--base path/to/base/index.html]
//   --base: also fail if anything outside the data block differs from the base file
//           (used to prove an event pull request changes event data only).

import { readFileSync } from "node:fs";
import vm from "node:vm";

const args = process.argv.slice(2);
const baseAt = args.indexOf("--base");
const baseFile = baseAt >= 0 ? args.splice(baseAt, 2)[1] : null;
const file = args[0] || "index.html";
const html = readFileSync(file, "utf8");

const MONTHS = ["January", "February", "March", "April", "May", "June", "July",
                "August", "September", "October", "November", "December"];
const ABBR = MONTHS.map(m => m.slice(0, 3));
const CONTINENTS = ["North America", "South America", "Europe", "Asia", "Africa", "Oceania", "Middle East", "TBA"];
const TYPES = ["Conference", "Regional"];
const YEAR = 2027;

function fail(problems) {
  console.error(`✗ ${file}: ${problems.length} problem${problems.length === 1 ? "" : "s"}`);
  for (const p of problems) console.error(`  - ${p}`);
  process.exit(1);
}

// The data block runs from the shared link constants to the first non-data constant.
const start = html.indexOf("const ROADSHOW");
const end = html.indexOf("const EXT_ICON");
if (start < 0 || end < 0 || end < start) {
  fail(["Could not find the data block (from `const ROADSHOW` to `const EXT_ICON`). Keep those markers in place."]);
}

if (baseFile) {
  const base = readFileSync(baseFile, "utf8");
  const bs = base.indexOf("const ROADSHOW"), be = base.indexOf("const EXT_ICON");
  if (bs < 0 || be < bs) fail([`${baseFile}: could not find the data block in the base file.`]);
  if (html.slice(0, start) !== base.slice(0, bs) || html.slice(end) !== base.slice(be)) {
    fail(["Changes outside the event data block (from `const ROADSHOW` to `const EXT_ICON`) are not allowed in an event pull request."]);
  }
}

// The block must be plain data: double-quoted strings, numbers, [ ] { } : , = ; and a few names.
// Checking this before evaluating it means nothing in it can run code.
{
  const code = html.slice(start, end).replace(/"(?:[^"\\\n]|\\.)*"/g, '""');
  const NAMES = new Set(["const", "true", "false", "d", "m", "n", "t", "city", "loc", "country", "cont", "url", "cfs", "tag"]);
  const bad = [];
  if (/[()`'\\$]|\/\*|\/\//.test(code)) bad.push("only double-quoted strings and plain values are allowed (found ( ) ` ' \\ $ or a comment)");
  for (const w of code.match(/[A-Za-z_][A-Za-z0-9_]*/g) || []) {
    if (!NAMES.has(w) && !/^[A-Z][A-Z0-9_]*$/.test(w)) { bad.push(`unexpected name "${w}"`); break; }
  }
  if (bad.length) fail(bad.map(b => `The data block must contain data only: ${b}.`));
}

let EVENTS, COORDS;
try {
  const ctx = {};
  vm.runInNewContext(html.slice(start, end) + "\n;globalThis.__data = { EVENTS, COORDS };", ctx, { timeout: 1000 });
  ({ EVENTS, COORDS } = ctx.__data);
} catch (e) {
  fail([`The data block is not valid JavaScript: ${e.message}`]);
}
if (!Array.isArray(EVENTS) || typeof COORDS !== "object") fail(["EVENTS must be an array and COORDS an object."]);

const daysIn = monthIdx => new Date(YEAR, monthIdx + 1, 0).getDate();
const RE_ONE   = new RegExp(`^(${ABBR.join("|")}) (\\d{1,2})$`);                                    // Feb 9
const RE_SAME  = new RegExp(`^(${ABBR.join("|")}) (\\d{1,2})–(\\d{1,2})$`);                         // Mar 8–12
const RE_CROSS = new RegExp(`^(${ABBR.join("|")}) (\\d{1,2}) – (${ABBR.join("|")}) (\\d{1,2})$`);   // Mar 30 – Apr 1

// Returns [monthIndex, startDay] for sorting, or a string describing what is wrong.
function parseDate(d, m) {
  if (d === "TBA") return m === "TBA" ? [12, 0] : `date is "TBA" but month is "${m}" (both must be "TBA")`;
  if (MONTHS.includes(d)) return m === d ? [MONTHS.indexOf(d), 32] : `month-only date "${d}" must have m:"${d}"`;
  let mi, day, endMi, endDay, x;
  if ((x = d.match(RE_ONE)))        { mi = ABBR.indexOf(x[1]); day = +x[2]; endMi = mi; endDay = day; }
  else if ((x = d.match(RE_SAME)))  { mi = ABBR.indexOf(x[1]); day = +x[2]; endMi = mi; endDay = +x[3];
                                      if (endDay <= day) return `range "${d}" must end after it starts`; }
  else if ((x = d.match(RE_CROSS))) { mi = ABBR.indexOf(x[1]); day = +x[2]; endMi = ABBR.indexOf(x[3]); endDay = +x[4];
                                      if (endMi <= mi) return `cross-month range "${d}" must end in a later month (use "Mar 8–12" for one month)`; }
  else return `date "${d}" is not in a recognised format ("Feb 9", "Mar 8–12" with an en dash, "Mar 30 – Apr 1", "March" or "TBA")`;
  if (day < 1 || day > daysIn(mi)) return `"${d}": ${ABBR[mi]} ${day} does not exist in ${YEAR}`;
  if (endDay < 1 || endDay > daysIn(endMi)) return `"${d}": ${ABBR[endMi]} ${endDay} does not exist in ${YEAR}`;
  if (m !== MONTHS[mi]) return `"${d}" starts in ${MONTHS[mi]}, so m must be "${MONTHS[mi]}" (found "${m}")`;
  return [mi, day];
}

const problems = [];
const seen = new Set();
let prev = null;

EVENTS.forEach((ev, i) => {
  const at = `EVENTS[${i}] (${ev && ev.n ? ev.n : "unnamed"})`;
  if (!ev || typeof ev !== "object") { problems.push(`${at}: not an object`); return; }

  for (const k of ["d", "m", "n", "t", "city", "loc", "country", "cont"]) {
    if (typeof ev[k] !== "string" || !ev[k].trim()) problems.push(`${at}: "${k}" is required`);
  }
  const allowed = new Set(["d", "m", "n", "t", "city", "loc", "country", "cont", "url", "cfs", "tag"]);
  for (const k of Object.keys(ev)) if (!allowed.has(k)) problems.push(`${at}: unknown field "${k}"`);

  if (!TYPES.includes(ev.t)) problems.push(`${at}: t must be "Conference" or "Regional" (found "${ev.t}")`);
  if (!CONTINENTS.includes(ev.cont)) problems.push(`${at}: cont "${ev.cont}" is not one of ${CONTINENTS.join(", ")}`);

  for (const k of ["d", "m", "n", "t", "city", "loc", "country", "cont", "url", "cfs", "tag"]) {
    if (ev[k] === undefined) continue;
    if (typeof ev[k] !== "string") { problems.push(`${at}: "${k}" must be a string`); continue; }
    if (/[<>"`\u0000-\u001f]/.test(ev[k])) problems.push(`${at}: "${k}" must not contain < > " \` or control characters`);
  }

  for (const k of ["url", "cfs"]) {
    if (ev[k] === undefined) continue;
    try { const u = new URL(ev[k]); if (u.protocol !== "https:" || /\s/.test(ev[k])) throw 0; }
    catch { problems.push(`${at}: ${k} "${ev[k]}" is not a valid https URL`); }
  }

  const tba = ev.city === "TBA";
  if (tba && (ev.country !== "TBA" || ev.cont !== "TBA")) problems.push(`${at}: city is "TBA", so country and cont must be "TBA" too`);
  if (!tba && (ev.country === "TBA" || ev.cont === "TBA")) problems.push(`${at}: country/cont are "TBA" but city is "${ev.city}"`);
  if (!tba) {
    const c = COORDS[ev.city];
    if (!Array.isArray(c) || c.length !== 2 || Math.abs(c[0]) > 90 || Math.abs(c[1]) > 180) {
      problems.push(`${at}: city "${ev.city}" needs a [latitude, longitude] entry in COORDS`);
    }
  }

  const key = `${ev.n}|${ev.d}`;
  if (seen.has(key)) problems.push(`${at}: duplicate of an earlier entry with the same name and date`);
  seen.add(key);

  const parsed = parseDate(ev.d, ev.m);
  if (typeof parsed === "string") { problems.push(`${at}: ${parsed}`); return; }
  if (prev && (parsed[0] < prev.key[0] || (parsed[0] === prev.key[0] && parsed[1] < prev.key[1]))) {
    problems.push(`${at}: out of date order — "${ev.d}" comes after "${prev.d}" (${prev.n})`);
  }
  prev = { key: parsed, d: ev.d, n: ev.n };
});

if (problems.length) fail(problems);
console.log(`✓ ${file}: ${EVENTS.length} events, ${Object.keys(COORDS).length} cities, all valid and in date order`);
