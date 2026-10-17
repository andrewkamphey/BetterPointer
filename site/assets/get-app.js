// Getting the app: what happens after Download, phones (which can't run it), and recipe
// "Add" links for people who don't have the app yet. Shared by the home page and /recipes.
(function () {
  var css = '' +
    '.ga{max-width:480px;width:calc(100% - 32px);padding:0;border:1px solid var(--line);border-radius:20px;background:var(--panel);color:var(--text);box-shadow:0 40px 120px rgba(0,0,0,.6)}' +
    '.ga::backdrop{background:rgba(5,6,12,.6);backdrop-filter:blur(4px)}' +
    '.ga .in{padding:24px 24px 20px}.ga h2{font-size:24px;margin:0 0 6px;letter-spacing:-.02em;line-height:1.15}' +
    '.ga .sub{color:var(--muted);margin:0 0 16px;font-size:15px}' +
    '.ga ol{margin:0;padding:0;list-style:none;counter-reset:s;display:grid;gap:12px}' +
    '.ga li{counter-increment:s;display:grid;grid-template-columns:28px 1fr;gap:12px;font-size:15px;line-height:1.45}' +
    '.ga li:before{content:counter(s);width:28px;height:28px;border-radius:50%;background:var(--text);color:#0d0e16;display:grid;place-items:center;font-weight:900;font-size:14px}' +
    '.ga li small{display:block;color:var(--faint);font-size:13px;margin-top:2px}' +
    '.ga .acts{display:flex;gap:10px;flex-wrap:wrap;margin-top:18px}' +
    '.ga .acts a,.ga .acts button{font:inherit;font-weight:800;font-size:14px;padding:9px 16px;border-radius:999px;cursor:pointer;border:1px solid var(--line);background:none;color:var(--text);text-decoration:none}' +
    '.ga .acts .pri{background:var(--text);color:#0d0e16;border-color:transparent}';
  var style = document.createElement('style');
  style.textContent = css;
  document.head.appendChild(style);

  function dialog(html) {
    var d = document.createElement('dialog');
    d.className = 'ga';
    d.innerHTML = '<div class="in">' + html + '</div>';
    document.body.appendChild(d);
    d.addEventListener('click', function (e) { if (e.target === d || e.target.closest('[data-close]')) d.close(); });
    return d;
  }
  function show(d) { if (typeof d.showModal === 'function' && !d.open) d.showModal(); }
  var track = function (name, params) { if (window.gtag) gtag('event', name, params || {}); };

  // After Download: the three steps, so Full Disk Access isn't a surprise.
  var after = dialog(
    '<h2>Your download has started</h2>' +
    '<p class="sub">Three steps and your pointer is impossible to miss.</p>' +
    '<ol>' +
    '<li><div>Open <b>WheresMyMouse.dmg</b> and drag the app to <b>Applications</b>.</div></li>' +
    '<li><div>Open it. A rainbow pointer appears in your menu bar; click it for every setting.</div></li>' +
    '<li><div>For colors, it asks for <b>Full Disk Access</b>.<small>macOS keeps pointer colors in its accessibility settings and only lets apps with this permission change them. Size works without it, and the app reads nothing else.</small></div></li>' +
    '</ol>' +
    '<div class="acts"><button type="button" class="pri" data-close>Got it</button><a href="/recipes">Browse Cursor Recipes</a></div>');

  // Phones can't run a Mac app: send the link to yourself instead of downloading a .dmg to the phone.
  var phone = window.matchMedia('(pointer: coarse)').matches && !/Macintosh/.test(navigator.userAgent);
  var share = dialog(
    '<h2>Get it on your Mac</h2>' +
    '<p class="sub">Where\'s My Mouse? is a Mac app, so send yourself the link and open it on your Mac.</p>' +
    '<div class="acts"><a class="pri" href="mailto:?subject=' + encodeURIComponent("Where's My Mouse? for my Mac") +
    '&body=' + encodeURIComponent('Download it here: https://wheresmymouse.com') + '" data-close>Email me the link</a>' +
    '<button type="button" data-copy>Copy link</button><button type="button" data-close>Close</button></div>');
  share.querySelector('[data-copy]').addEventListener('click', function (e) {
    var b = e.currentTarget;
    (navigator.clipboard ? navigator.clipboard.writeText('https://wheresmymouse.com') : Promise.reject()).then(function () { b.textContent = 'Copied'; }, function () { b.textContent = 'wheresmymouse.com'; });
  });
  if (phone) {
    document.querySelectorAll('a[href*="/download"] .dl-label').forEach(function (l) { l.textContent = 'Send it to my Mac'; });
  }

  // Recipe "Add" links only work with the app installed; the first one explains.
  var addTarget = null;
  var add = dialog(
    '<h2>Add it to Where\'s My Mouse?</h2>' +
    '<p class="sub">“Add to app” opens Where\'s My Mouse? on this Mac and asks before saving the recipe as a preset.</p>' +
    '<div class="acts"><button type="button" class="pri" data-have>I have the app, add it</button>' +
    '<a href="https://wheresmymouse.com/download" data-close>Download free first</a></div>');
  add.querySelector('[data-have]').addEventListener('click', function () {
    try { localStorage.setItem('wmm-has-app', '1'); } catch (e) {}
    add.close();
    if (addTarget) location.href = addTarget;
  });
  function hasApp() { try { return localStorage.getItem('wmm-has-app') === '1'; } catch (e) { return false; } }

  document.addEventListener('click', function (e) {
    var a = e.target.closest && e.target.closest('a');
    if (!a) return;
    if (a.matches('a[href*="/download"]')) {
      if (phone) { e.preventDefault(); show(share); track('send_to_mac'); return; }
      try { localStorage.setItem('wmm-has-app', '1'); } catch (err) {}
      setTimeout(function () { show(after); }, 400); // let the download start first
      return;
    }
    if (a.matches('.rc-add') && !hasApp()) {
      e.preventDefault();
      e.stopPropagation();
      addTarget = a.href;
      show(add);
    }
  }, true);
})();
