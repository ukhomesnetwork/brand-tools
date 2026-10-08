// Renders the Gatha social covers to PNG.
//   node render.mjs            -> exports/
//   node render.mjs --guides   -> exports/previews/ with safe-zone overlays
import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';
import { mkdirSync, readFileSync } from 'node:fs';
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
  { f: 'youtube',           w: 1280, h: 720, scales: [2],    name: s => 'gatha-youtube-banner-2560x1440.png' },
  { f: 'youtube-icon',      w: 400,  h: 400, scales: [2],    name: s => 'gatha-youtube-icon-800x800.png' },
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
// YouTube video watermark: 150 x 150, transparent, pink mark only
if (!guides) {
  const page = await browser.newPage({ viewport: { width: 150, height: 150 }, deviceScaleFactor: 1 });
  const mark = readFileSync(join(here, 'assets', 'gatha-mark.svg'), 'utf8').replace(/<\?xml[^>]*>/, '');
  await page.setContent(`<style>html,body{margin:0;background:transparent}svg{display:block;width:150px;height:150px}</style>${mark}`);
  await page.waitForLoadState('load');
  const file = join(outDir, 'gatha-youtube-watermark-150x150.png');
  await page.screenshot({ path: file, omitBackground: true });
  console.log('wrote', file);
  await page.close();
}
await browser.close();
