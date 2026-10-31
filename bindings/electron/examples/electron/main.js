// Run: npm run example   (from bindings/electron, after npm run build)
// Env: PG_KIND=accessibility|screen-recording|input-monitoring, PG_DISMISS_MS=ms (auto dismiss, default 5000)
const { app } = require('electron');
const pg = require('../../dist');

const kind = process.env.PG_KIND || 'accessibility';
app.whenReady().then(async () => {
  console.log('status before:', pg.status(kind));
  setTimeout(() => { console.log('dismissing'); pg.dismiss(); }, Number(process.env.PG_DISMISS_MS || 5000));
  const granted = await pg.present(kind, { appName: 'PG Example' });
  console.log('present resolved:', granted);
  console.log('status after:', pg.status(kind));
  app.quit();
});
app.on('window-all-closed', () => {});
