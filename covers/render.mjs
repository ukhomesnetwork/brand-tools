// Renders the Gatha social covers to PNG.
//   node render.mjs            -> exports/
//   node render.mjs --guides   -> exports/previews/ with safe-zone overlays
import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';
import { mkdirSync } from 'node:fs';
import { execSync } from 'node:child_process';

const require = createRequire(import.meta.url);
let playwright;
try { playwright = require('playwright'); }
catch { playwright = require(join(execSync('npm root -g').toString().trim(), 'playwright')); }

const here = dirname(fileURLToPath(import.meta.url));
const guides = process.argv.includes('--guides');
const outDir = join(here, 'exports', guides ? 'previews' : '');
mkdirSync(outDir, { recursive: true });

const JOBS = [
  { f: 'facebook',          w: 820,  h: 312, scales: [2],    name: s => 'gatha-facebook-cover-1640x624.png' },
  { f: 'linkedin-company',  w: 1128, h: 191, scales: [1, 2], name: s => `gatha-linkedin-company-cover-${1128*s}x${191*s}.png` },
  { f: 'linkedin-personal', w: 1584, h: 396, scales: [1, 2], name: s => `gatha-linkedin-personal-banner-${1584*s}x${396*s}.png` },
];

const browser = await playwright.chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined });
for (const job of JOBS) {
  for (const scale of guides ? [1] : job.scales) {
    const page = await browser.newPage({ viewport: { width: job.w, height: job.h }, deviceScaleFactor: scale });
    const url = pathToFileURL(join(here, 'cover.html')).href + `?f=${job.f}${guides ? '&guides=1' : ''}`;
    await page.goto(url);
    await page.waitForSelector('body[data-ready="1"]');
    await page.waitForTimeout(150);
    const file = join(outDir, guides ? `${job.f}-guides.png` : job.name(scale));
    await page.locator('#cover').screenshot({ path: file });
    console.log('wrote', file);
    await page.close();
  }
}
await browser.close();
