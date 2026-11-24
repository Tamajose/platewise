const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');
const url = process.env.PLATEWISE_WEB_URL || 'http://127.0.0.1:8011';
const output = process.env.PLATEWISE_EVIDENCE_DIR || path.resolve('testdata/browser-evidence');
const record = process.env.PLATEWISE_RECORD === '1';
const pause = record ? 500 : 100;
fs.mkdirSync(output, { recursive: true });

async function main() {
  const browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_PATH,
    args: ['--no-sandbox', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
  });
  const typical = { width: 402, height: 870 };
  const context = await browser.newContext({
    viewport: typical, deviceScaleFactor: 1, isMobile: true, hasTouch: true,
    ...(record ? { recordVideo: { dir: output, size: typical } } : {}),
    reducedMotion: 'reduce',
  });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (error) => errors.push(error.message));
  const heading = (name) => page.getByRole('heading', { name, exact: true }).or(
    page.getByRole('banner', { name: new RegExp('^' + name.replace(/[|\\{}()[\]^$+*?.]/g, '\\$&')) })).first();
  const button = (name) => page.getByRole('button', { name, exact: true });
  const visible = (pattern) => page.locator('flt-semantics').filter({ hasText: pattern }).last();
  const shot = async (name) => {
    await page.waitForTimeout(pause);
    await page.screenshot({ path: path.join(output, name + '.png') });
  };
  const seek = async (target) => {
    for (let step = 0; step < 7; step++) {
      if (await target.count() && await target.first().isVisible()) return target.first();
      await page.mouse.move(180, Math.min(page.viewportSize().height - 100, 550));
      await page.mouse.wheel(0, 340);
      await page.waitForTimeout(115);
    }
    return target.first();
  };
  const tap = async (name) => {
    const target = await seek(button(name));
    try { await target.click({ timeout: 3500 }); }
    catch { await target.focus(); await page.keyboard.press('Enter'); }
    await page.waitForTimeout(pause);
  };
  const enable = async () => {
    await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 20000 });
    await page.locator('flt-semantics-placeholder').evaluate((node) => node.click());
  };
  const field = async (label, value) => {
    const target = await seek(page.getByRole('textbox', { name: label }));
    await target.click({timeout: 7000});
    await page.waitForTimeout(160);
    await target.press('Control+a');
    await page.keyboard.type(value, {delay: 70});
    if (await target.inputValue() !== value) await target.fill(value, {timeout:6000});
    await page.keyboard.press('Tab');
    await page.waitForTimeout(160);
  };
  const tab = async (name) => {
    const bar = page.getByRole('tab', {name: new RegExp(name)});
    if (await bar.count() > 0) await bar.first().click();
    else await page.getByText(name, {exact: true}).last().click();
    await heading(name).waitFor({ timeout:10000 });
  };
  const metrics = {};
  try {
    const cold = performance.now();
    await page.goto(url, { waitUntil: 'networkidle', timeout: 55000 });
    await enable();
    await heading('Decide before you eat').waitFor();
    await shot('01-welcome');
    await tap('Explore a sample day');
    await heading('Today').waitFor();
    await shot('02-today');
    await tap('Log meal');
    await heading('Log meal').waitFor();
    await shot('03-capture');
    await tap('Review sample photo estimate');
    await heading('Review meal').waitFor();
    await shot('04-review');

    const confirmStart = performance.now();
    await button('Confirm and log meal').click({timeout:8000});
    await heading('Today').waitFor();
    await visible('Chicken tikka rice bowl · Masoor dal').waitFor({timeout:10000});
    metrics.demo_confirm_to_updated_today_ms = Math.round(performance.now() - confirmStart);
    metrics.demo_sample_launch_to_first_new_meal_ms = Math.round(performance.now() - cold);

    await tab('Decide');
    await shot('05-decide');
    await tap('Set a meal budget');
    await field('Meal budget (kcal)', '650');
    await page.keyboard.press('Tab');
    await tap('Review sample menu');
    await heading('Review menu').waitFor();
    await shot('06-menu-review');
    await tap('Compare selected dishes');
    await (await seek(button('Choose this meal'))).waitFor({timeout:10000});
    await button('Choose this meal').first().scrollIntoViewIfNeeded();
    await shot('07-comparison');
    await button('Choose this meal').first().click();
    await heading('Review meal').waitFor();
    const changeFood = await seek(page.getByRole('button', {name: /^Edit (Vegetable|Chicken)/}));
    await changeFood.click();
    await field('Quantity', '2');
    await tap('Apply food changes');
    await button('Confirm and log meal').waitFor({timeout:8000});
    await shot('07b-edited-draft');
    await tap('Confirm and log meal');
    await heading('Today').waitFor();

    await tab('Nearby');
    await tap('Sample menus');
    await (await seek(button('Review this meal'))).waitFor({timeout:10000});
    await shot('08-nearby');
    await tab('Today');
    await tap('+250 ml');
    await tap('Open water log');
    await heading('Water').waitFor();
    await shot('09-water');
    await tap('Back');
    await heading('Today').waitFor();
    await tab('Progress');
    await shot('10-progress');
    await tap('Settings and profile');
    await heading('Settings').waitFor();
    await shot('11-settings');

    await page.setViewportSize({width: 320, height: 700});
    await page.reload({waitUntil:'networkidle'});
    await enable();
    await heading('Progress').waitFor();
    await tap('Settings and profile');
    await heading('Settings').waitFor();
    await shot('12-small-settings');
    await tap('Clear demo data');
    await tap('Delete data');
    await heading('Decide before you eat').waitFor();
    await tap('Set up my profile');
    await heading('Set up your profile').waitFor();
    await shot('13-onboarding');
    await field('Height (cm)', '170');
    await field('Weight (kg)', '69');
    await tap('Continue to Today');
    await heading('Today').waitFor();
    await heading('No meals logged yet').waitFor();
    await shot('14-today-empty');

    assert.deepEqual(errors, []);
    fs.writeFileSync(path.join(output, 'browser-result.json'), JSON.stringify({ ...metrics, javascript_errors: 0 }, null, 2));
    console.log(JSON.stringify(metrics));
  } catch (error) {
    await page.screenshot({ path: path.join(output, 'failure.png') });
    console.error('Page', page.url(), '\n', await page.locator('body').ariaSnapshot());
    throw error;
  } finally {
    await context.close();
    const video = page.video();
    if (video) fs.renameSync(await video.path(), path.join(output, 'platewise-demo.webm'));
    await browser.close();
  }
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
