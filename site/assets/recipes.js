// Cursor Recipes: preview background switch, size slider, recipe of the month, and the /recipes filters.
(function () {
  // Pointer height in a preview: big at every size, still growing up to 30x. Matches scripts/build_recipes.py.
  function height(s) { return 40 + 56 * Math.log(s + 1) / Math.log(31); }
  function fmt(s) { return (s % 1 ? s.toFixed(1) : String(s)) + '×'; }

  function setMode(pv, mode) {
    pv.dataset.mode = mode;
    pv.querySelectorAll('.rc-mode button').forEach(function (b) { b.setAttribute('aria-pressed', String(b.dataset.mode === mode)); });
  }

  function setSize(r, s) {
    r.querySelectorAll('.rc-ar').forEach(function (a) { a.style.setProperty('--h', height(s).toFixed(1) + '%'); });
    r.querySelectorAll('.rc-sz b').forEach(function (b) { b.textContent = fmt(s); });
    var input = r.querySelector('.rc-edit input'), hint = r.querySelector('.rc-hint');
    if (input) input.value = s;
    if (hint) hint.textContent = s > 15 ? 'Above 15×: turn on Extra large in the menu.'
      : s === +r.dataset.size ? 'Recipe size. Drag to try others.' : 'Recipe is ' + fmt(+r.dataset.size) + '.';
  }

  document.addEventListener('click', function (e) {
    var mode = e.target.closest('.rc-mode button');
    if (mode) { setMode(mode.closest('.rc-pv'), mode.dataset.mode); return; }
    var sz = e.target.closest('.rc-sz');
    if (sz) {
      var edit = sz.closest('[data-size]').querySelector('.rc-edit');
      edit.hidden = !edit.hidden;
      sz.setAttribute('aria-expanded', String(!edit.hidden));
      if (!edit.hidden) edit.querySelector('input').focus();
      return;
    }
    var reset = e.target.closest('.rc-reset');
    if (reset) { var r = reset.closest('[data-size]'); setSize(r, +r.dataset.size); }
  });
  document.addEventListener('input', function (e) {
    if (e.target.matches('.rc-edit input')) setSize(e.target.closest('[data-size]'), +e.target.value);
  });

  // Home: swap in this month's recipe (the page ships with October's).
  var months = document.getElementById('rc-months'), feature = document.querySelector('.rc-feature');
  if (months && feature) {
    var r = JSON.parse(months.textContent)[new Date().getMonth()];
    var name = new Date().toLocaleString('en-US', { month: 'long' });
    feature.dataset.size = r.size;
    feature.querySelector('.rc-kick').textContent = 'Recipe of the month · ' + name;
    feature.querySelector('h3').textContent = r.name;
    feature.querySelector('p').textContent = r.blurb;
    feature.querySelectorAll('.rc-ar use').forEach(function (u) { u.setAttribute('fill', r.fill); u.setAttribute('stroke', r.outline); });
    feature.querySelector('[data-k=fill]').innerHTML = '<i style="background:' + r.fill + '"></i>' + r.fill;
    feature.querySelector('[data-k=outline]').innerHTML = '<i style="background:' + r.outline + '"></i>' + r.outline;
    feature.querySelector('.rc-link').href = '/recipes#' + r.id;
    feature.querySelector('.rc-edit input').setAttribute('aria-label', 'Preview size for ' + r.name);
    setSize(feature, r.size);
  }

  // /recipes: category filter, background for every card, cards or list.
  var page = document.getElementById('rc-page');
  if (!page) return;
  function group(name, fn) {
    var buttons = page.querySelectorAll('[data-' + name + ']');
    buttons.forEach(function (b) {
      b.addEventListener('click', function () {
        buttons.forEach(function (q) { q.setAttribute('aria-pressed', String(q === b)); });
        fn(b.dataset[name]);
      });
    });
  }
  group('filter', function (f) {
    page.querySelectorAll('.rc-card, .rc-row').forEach(function (el) { el.hidden = f !== 'all' && el.dataset.cat !== f; });
  });
  group('bg', function (m) { page.querySelectorAll('.rc-card .rc-pv').forEach(function (pv) { setMode(pv, m); }); });
  group('view', function (v) {
    document.getElementById('rc-grid').hidden = v !== 'cards';
    document.getElementById('rc-list').hidden = v !== 'list';
    page.querySelector('[aria-label=Background]').hidden = v === 'list'; // list rows always show both

  });
})();
