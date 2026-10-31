// Same calls as the guest API (guest-js/index.ts), via the global Tauri object.
const { invoke } = window.__TAURI__.core
const { listen } = window.__TAURI__.event
const P = 'plugin:permission-guide|'
const log = (m) => { document.getElementById('log').textContent += m + '\n' }
listen('permission-guide://result', (e) => log('result ' + JSON.stringify(e.payload)))
document.getElementById('st').onclick = async () => log('status ' + (await invoke(P + 'status', { kind: 'accessibility' })))
document.getElementById('pr').onclick = async () => { await invoke(P + 'present', { kind: 'accessibility' }); log('present returned') }
document.getElementById('di').onclick = async () => { await invoke(P + 'dismiss'); log('dismiss returned') }
