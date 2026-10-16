// First launch help: the app isn't notarized yet, so macOS blocks the first open.
// Clicking Download (the download still starts) or any [data-first-launch] link shows the one-time fix.
(function () {
  var css = '' +
    '#fl{max-width:520px;width:calc(100% - 32px);padding:0;border:1px solid var(--line);border-radius:20px;background:var(--panel);color:var(--text);box-shadow:0 40px 120px rgba(0,0,0,.6)}' +
    '#fl::backdrop{background:rgba(5,6,12,.6);backdrop-filter:blur(4px)}' +
    '#fl .in{padding:26px 26px 22px}#fl h2{font-size:26px;margin:0 0 6px;letter-spacing:-.02em;line-height:1.1}' +
    '#fl .sub{color:var(--muted);margin:0 0 18px;font-size:15px}' +
    '#fl ol{margin:0;padding:0;list-style:none;counter-reset:s;display:grid;gap:14px}' +
    '#fl li{counter-increment:s;display:grid;grid-template-columns:30px 1fr;gap:12px;font-size:16px;line-height:1.45}' +
    '#fl li:before{content:counter(s);width:30px;height:30px;border-radius:50%;background:var(--text);color:#0d0e16;display:grid;place-items:center;font-weight:900}' +
    '#fl li small{display:block;color:var(--faint);font-size:13px;margin-top:2px}' +
    '#fl .acts{display:flex;gap:10px;flex-wrap:wrap;margin-top:20px}' +
    '#fl .acts a,#fl .acts button{font:inherit;font-weight:800;font-size:14px;padding:9px 16px;border-radius:999px;cursor:pointer;border:1px solid var(--line);background:none;color:var(--text)}' +
    '#fl .acts .pri{background:var(--text);color:#0d0e16;border-color:transparent}#fl .acts a:hover{text-decoration:none}' +
    '#fl details{margin-top:16px;color:var(--muted);font-size:14px}#fl summary{cursor:pointer}' +
    '#fl code{display:block;margin-top:8px;padding:10px 12px;border-radius:10px;background:#0d0e16;color:var(--text);font:12.5px ui-monospace,Menlo,monospace;word-break:break-all}';
  var style = document.createElement('style');
  style.textContent = css;
  document.head.appendChild(style);

  var cmd = 'xattr -dr com.apple.quarantine "/Applications/Where\'s My Mouse.app"';
  var d = document.createElement('dialog');
  d.id = 'fl';
  d.setAttribute('aria-labelledby', 'fl-title');
  d.innerHTML = '<div class="in">' +
    '<h2 id="fl-title">One more step on first launch</h2>' +
    '<p class="sub" id="fl-sub">macOS will say it can\'t verify the app. That\'s because it isn\'t notarized by Apple yet (the code is <a href="https://github.com/andrewkamphey/WheresMyMouse">open source</a>). Here\'s the one-time fix:</p>' +
    '<ol>' +
    '<li><div>Open the download and drag <b>Where\'s My Mouse?</b> to Applications, then open it.</div></li>' +
    '<li><div>When macOS warns you, click <b>Done</b>.</div></li>' +
    '<li><div>Open <b>System Settings → Privacy &amp; Security</b>, scroll down, and click <b>Open Anyway</b>. Then open the app again.<small>Only needed once.</small></div></li>' +
    '</ol>' +
    '<div class="acts"><a class="pri" href="x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension">Open Privacy &amp; Security</a>' +
    '<button type="button" value="close">Got it</button></div>' +
    '<details><summary>Prefer Terminal?</summary>Run this once instead of step 3:<code>' + cmd.replace(/&/g, '&amp;').replace(/</g, '&lt;') + '</code></details>' +
    '</div>';
  document.body.appendChild(d);
  d.querySelector('button').addEventListener('click', function () { d.close(); });
  d.addEventListener('click', function (e) { if (e.target === d) d.close(); }); // click outside closes

  function show(downloading) {
    d.querySelector('#fl-title').textContent = downloading ? 'Downloading… one more step' : 'One more step on first launch';
    if (typeof d.showModal === 'function' && !d.open) d.showModal();
  }
  document.addEventListener('click', function (e) {
    var help = e.target.closest && e.target.closest('[data-first-launch]');
    if (help) { e.preventDefault(); show(false); return; }
    var dl = e.target.closest && e.target.closest('a[href*="/download"]');
    if (dl) setTimeout(function () { show(true); }, 400); // let the download start first
  });
})();
