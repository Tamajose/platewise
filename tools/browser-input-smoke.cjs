const assert = require('node:assert/strict');
const path = require('node:path');
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_PATH,
    args: ['--no-sandbox', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
  });
  try {
    const page = await browser.newPage({viewport: {width: 402, height: 870}});
    await page.addInitScript(() => {
      const query = navigator.permissions.query.bind(navigator.permissions);
      navigator.permissions.query = (permission) => permission.name === 'geolocation'
        ? Promise.resolve({state: 'denied', addEventListener() {}, removeEventListener() {}})
        : query(permission);
    });
    await page.goto(process.env.PLATEWISE_WEB_URL || 'http://127.0.0.1:8011', {waitUntil: 'networkidle'});
    await page.locator('flt-semantics-placeholder').evaluate((node) => node.click());
    const button = (name) => page.getByRole('button', {name, exact: true});
    const heading = (name) => page.getByRole('heading', {name, exact: true});
    const output = process.env.PLATEWISE_EVIDENCE_DIR;
    await button('Explore a sample day').click();
    await heading('Today').waitFor();
    await button('Log meal').click();
    await page.getByRole('checkbox', {name: 'Voice', exact: true}).click();
    await button('Use sample transcript').click();
    const transcript = page.getByRole('textbox', {name: 'Review or type transcript'});
    await transcript.click();
    await page.waitForTimeout(180);
    await transcript.fill('One cup of rice');
    assert.equal(await transcript.inputValue(), 'One cup of rice');
    await page.keyboard.press('Tab');
    if (output) await page.screenshot({path: path.join(output, '15-voice-edit.png')});
    await button('Estimate meal').click();
    await heading('Review meal').waitFor();
    const estimate = await page.locator('body').ariaSnapshot();
    assert.match(estimate, /Voice transcript/);
    assert.match(estimate, /Steamed rice/);
    assert.doesNotMatch(estimate, /Masoor dal/);
    await page.goto((process.env.PLATEWISE_WEB_URL || 'http://127.0.0.1:8011').replace(/\/$/, '') + '/#/nearby', {waitUntil:'networkidle'});
    const enable = page.locator('flt-semantics-placeholder');
    if (await enable.count()) await enable.evaluate((node) => node.click());
    await heading('Nearby').waitFor();
    const location = button('Use my location');
    await location.click({ force: true, timeout: 8000 });
    await button('Try again').waitFor({timeout:8000});
    assert.match(await page.locator('body').ariaSnapshot(), /Select a location/);
    await button('Enter coordinates').waitFor();
    await page.mouse.move(175, 650);
    await page.mouse.wheel(0, 290);
    await page.waitForTimeout(250);
    if (output) await page.screenshot({path: path.join(output, '16-location-denied.png')});
    console.log('Editable sample voice reached text estimation; simulated location denial kept manual selection available.');
  } finally { await browser.close(); }
})().catch((error) => { console.error(error); process.exitCode = 1; });
