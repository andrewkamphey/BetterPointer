#!/usr/bin/env python3
"""Builds the Cursor Recipes: site/recipes.html and the home page section in site/index.html
(between the recipes:start/end markers). Edit RECIPES or MONTHS here, then run:
    python3 scripts/build_recipes.py
Styles and behavior live in site/assets/recipes.css and recipes.js."""
import html, json, re
from pathlib import Path

SITE = Path(__file__).resolve().parent.parent / "site"
CATS = {"seasonal": "Seasonal", "pop": "Pop culture", "world": "Around the world", "classic": "Classics"}

# name, category, size, fill, outline, blurb
RECIPES = [
    ("Sakura Spring", "seasonal", 4, "#FFB7C5", "#7A2E45", "Cherry blossom pink for the first warm week."),
    ("Summer Sunburst", "seasonal", 5, "#FFD60A", "#1D1D1F", "Bright as a beach umbrella."),
    ("Pumpkin Patch", "seasonal", 6, "#FF7518", "#3B1F0E", "Orange and roasty, for September."),
    ("Winter Frost", "seasonal", 4, "#E6F7FF", "#1F4E79", "Pale ice with a deep winter edge."),
    ("Spooky Season", "seasonal", 8, "#1D1D1F", "#FF7518", "Black cat with a jack-o'-lantern glow."),
    ("Candy Cane", "seasonal", 5, "#E3262F", "#FFFFFF", "Red and white, very December."),
    ("Lunar New Year", "seasonal", 6, "#D7261E", "#FFD700", "Red for luck, gold for prosperity."),
    ("Diwali Marigold", "seasonal", 5, "#FFB000", "#8A1C00", "Warm marigold for the festival of lights."),
    ("Barbiecore", "pop", 6, "#E0218A", "#FFFFFF", "Hot pink, unapologetically."),
    ("Hacker Green", "pop", 3, "#00FF41", "#000000", "Terminal green on pitch black."),
    ("Vaporwave", "pop", 5, "#FF71CE", "#01CDFE", "Pink and cyan, straight out of 1995."),
    ("Synthwave Sunset", "pop", 7, "#FF6C11", "#2D1B69", "Neon orange over a purple grid."),
    ("Y2K Chrome", "pop", 4, "#C9CED6", "#4B2A85", "Brushed silver with a millennium edge."),
    ("Slime Time", "pop", 8, "#7FFF00", "#3A0F5C", "Gooey green, game-show purple."),
    ("Retro Arcade", "pop", 10, "#FFE81F", "#E3262F", "Insert coin. Big and blocky."),
    ("Main Character", "pop", 15, "#FFFFFF", "#000000", "Center stage. Everyone's looking."),
    ("Rosa Mexicano", "world", 5, "#E4007C", "#FFFFFF", "Mexico's bold, iconic pink."),
    ("Majorelle Blue", "world", 5, "#6050DC", "#FFD43B", "The vivid blue of a Marrakech garden."),
    ("Klein Blue", "world", 6, "#002FA7", "#FFFFFF", "France's deepest, most famous blue."),
    ("British Racing Green", "world", 5, "#004225", "#F2E8C9", "Classic motorsport green with cream."),
    ("Rosso Corsa", "world", 6, "#D40000", "#FFFFFF", "Italian racing red."),
    ("Dutch Oranje", "world", 5, "#FF6600", "#1D1D1F", "The Netherlands' national orange."),
    ("Shu-iro Vermilion", "world", 4, "#EB6101", "#FFFFFF", "The vermilion of Japanese shrine gates."),
    ("Celadon", "world", 4, "#ACE1AF", "#2F5D3A", "Pale jade glaze from Chinese pottery."),
    ("Highlighter", "classic", 4, "#E7FF00", "#000000", "The marker on every textbook page."),
    ("Teacher's Red Pen", "classic", 6, "#FF3B30", "#FFFFFF", "Circle the mistake. Everyone sees it."),
    ("Construction Zone", "classic", 8, "#FFC300", "#000000", "Hi-vis yellow, hard to ignore."),
    ("Night Owl", "classic", 3, "#FFFFFF", "#000000", "A white pointer for dark mode."),
    ("Ocean", "classic", 4, "#0A84FF", "#FFFFFF", "Calm, clear and easy to follow."),
    ("Grape Soda", "classic", 5, "#AF52DE", "#FFFFFF", "Fizzy purple."),
    ("Billboard", "classic", 15, "#FF2D55", "#FFD60A", "Readable from the back row."),
    ("Stealth", "classic", 1, "#000000", "#000000", "Default size, no outline. Good luck."),
]
# Recipe of the month, January to December.
MONTHS = ["Winter Frost", "Lunar New Year", "Sakura Spring", "Celadon", "Rosa Mexicano", "Summer Sunburst",
          "Vaporwave", "Highlighter", "Pumpkin Patch", "Spooky Season", "Diwali Marigold", "Candy Cane"]
HOME_LIST = ["Barbiecore", "Hacker Green", "Majorelle Blue", "Rosso Corsa", "Vaporwave", "Klein Blue"]
SHIPPED_MONTH = 9  # the home page HTML ships with October's recipe; recipes.js swaps in the current month

E = html.escape
def slug(n): return re.sub(r"[^a-z0-9]+", "-", n.lower().replace("'", "")).strip("-")
def h(s): return s / 15 * 92  # true to scale: 15x fills the preview, bigger spills off the edges. Same as recipes.js
BY = {r[0]: r for r in RECIPES}
PENCIL = '<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M11.5 1.5l3 3L5 14H2v-3z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/></svg>'

def arrow(f, o, s): return f'<svg class="rc-ar" viewBox="0 0 62 100" style="--h:{h(s):.1f}%" aria-hidden="true"><use href="#arrow" fill="{f}" stroke="{o}"/></svg>'
def split(f, o, s):
    return (f'<div class="rc-shot"><div class="rc-pv" data-mode="split"><div class="rc-half l"></div><div class="rc-half d"></div>{arrow(f, o, s)}'
            '<span class="rc-lbl l">Light</span><span class="rc-lbl d">Dark</span></div>'
            '<div class="rc-mode" role="group" aria-label="Background">'
            '<button type="button" data-mode="split" aria-pressed="true">◐ Split</button>'
            '<button type="button" data-mode="light" aria-pressed="false">☀ Light</button>'
            '<button type="button" data-mode="dark" aria-pressed="false">☾ Dark</button></div></div>')
def pair(f, o, s): return f'<div class="rc-pair"><div class="rc-pv solid-l">{arrow(f, o, s)}</div><div class="rc-pv solid-d">{arrow(f, o, s)}</div></div>'
def size_btn(n, s): return f'<button type="button" class="rc-sz" aria-expanded="false" aria-label="Try {E(n)} at other sizes"><b>{s}×</b>{PENCIL}</button>'
def size_edit(n, s):
    return (f'<div class="rc-edit" hidden><input type="range" min="1" max="30" step="0.5" value="{s}" aria-label="Preview size for {E(n)}">'
            '<button type="button" class="rc-reset">Reset</button><span class="rc-hint">Recipe size. Drag to try others.</span></div>')
def chips(f, o): return f'<span class="rc-chips"><span class="rc-chip"><i style="background:{f}"></i>{f}</span><span class="rc-chip"><i style="background:{o}"></i>{o}</span></span>'

def card(r):
    n, c, s, f, o, d = r
    return (f'<article class="rc-card" id="{slug(n)}" data-cat="{c}" data-size="{s}">{split(f, o, s)}<div class="rc-body">'
            f'<div class="rc-head"><h3>{E(n)}</h3>{size_btn(n, s)}</div>{size_edit(n, s)}<p>{E(d)}</p>{chips(f, o)}</div></article>')
def row(r):
    n, c, s, f, o, d = r
    return (f'<div class="rc-row" data-cat="{c}" data-size="{s}">{pair(f, o, s)}<h4>{E(n)}</h4><span class="rc-cat">{CATS[c]}</span>'
            f'<span>{size_btn(n, s)}</span>{chips(f, o)}{size_edit(n, s)}</div>')

def home():
    n, c, s, f, o, d = BY[MONTHS[SHIPPED_MONTH]]
    months = json.dumps([dict(zip(("name", "cat", "size", "fill", "outline", "blurb"), BY[m]), id=slug(m)) for m in MONTHS])
    return f'''<section id="recipes">
  <div class="wrap">
    <h2>Cursor Recipes</h2>
    <p class="lead">Ready-made looks: seasonal, pop culture, and famous colors from around the world. Set the size, fill and outline in the menu and save it as a preset.</p>
    <div class="rc-month">
      <article class="rc-card rc-feature" data-size="{s}">{split(f, o, s)}<div class="rc-body">
        <span class="rc-kick">Recipe of the month · October</span>
        <h3>{E(n)}</h3>
        <p>{E(d)}</p>
        <dl class="rc-spec">
          <div><dt>Size</dt><dd>{size_btn(n, s)}</dd></div>
          {size_edit(n, s)}
          <div><dt>Fill</dt><dd data-k="fill"><i style="background:{f}"></i>{f}</dd></div>
          <div><dt>Outline</dt><dd data-k="outline"><i style="background:{o}"></i>{o}</dd></div>
        </dl>
        <a class="rc-link" href="/recipes#{slug(n)}">Open in the gallery →</a>
      </div></article>
      <div class="rc-list rc-more">
        <div class="rc-more-h">More recipes</div>
        {"".join(row(BY[m]) for m in HOME_LIST)}
        <a class="rc-all" href="/recipes">See all {len(RECIPES)} recipes →</a>
      </div>
    </div>
  </div>
  <script type="application/json" id="rc-months">{months}</script>
</section>'''

def page(index):
    root = re.search(r"  :root \{.*?\n  \}", index, re.S).group(0)
    base = index[index.index("  * { box-sizing"):index.index("  /* hero */")]
    foot = re.search(r"  footer \{.*?\n  footer \.wrap \{[^\n]*\n", index, re.S).group(0)
    head = index[:index.index("<title>")]
    arrow_def = re.search(r'<svg width="0".*?</svg>', index, re.S).group(0)
    footer = re.search(r"<footer>.*?</footer>", index, re.S).group(0)
    seg = lambda key, items, on: "".join(f'<button type="button" data-{key}="{k}" aria-pressed="{str(k == on).lower()}">{v}</button>' for k, v in items)
    filters = seg("filter", [("all", "All")] + list(CATS.items()), "all")
    return f'''{head}<title>Cursor Recipes — Where's My Mouse?</title>
<meta name="description" content="{len(RECIPES)} ready-made Mac pointer looks: seasonal, pop culture and famous colors from around the world, each with its size, fill and outline for Where's My Mouse?.">
<link rel="icon" type="image/png" href="assets/favicon.png">
<link rel="apple-touch-icon" href="assets/icon.png">
<meta property="og:title" content="Cursor Recipes — Where's My Mouse?">
<meta property="og:description" content="Ready-made Mac pointer looks with exact sizes and colors.">
<meta property="og:image" content="https://wheresmymouse.com/assets/og.png">
<meta property="og:url" content="https://wheresmymouse.com/recipes">
<meta name="twitter:card" content="summary_large_image">
<link rel="canonical" href="https://wheresmymouse.com/recipes">
<style>
{root}
{base}
  .rc-hero {{ padding: 24px 0 8px; }}
  .rc-hero h1 {{ font-size: clamp(44px, 7vw, 84px); line-height: 0.95; letter-spacing: -0.04em; margin: 10px 0 14px; font-weight: 900; }}
  .rc-hero p {{ color: var(--muted); font-size: 19px; max-width: 680px; margin: 0; }}
  .rc-hero .fine {{ color: var(--faint); font-size: 14px; margin-top: 10px; }}
  .dl {{ background: var(--text); color: #0d0e16 !important; font-weight: 800; padding: 6px 14px; border-radius: 999px; }}
  .dl:hover {{ text-decoration: none; }}
  main {{ padding-bottom: 72px; }}
{foot}  @media (max-width: 560px) {{ nav .links a.hide-sm {{ display: none; }} }}
</style>
<link rel="stylesheet" href="assets/recipes.css">
</head>
<body>
{arrow_def}
<div class="wrap">
  <nav>
    <a class="brand" href="/"><img src="assets/icon.png" alt="">Where's My Mouse?</a>
    <div class="links">
      <a class="hide-sm" href="/#features">Features</a>
      <a class="hide-sm" href="/#faq">FAQ</a>
      <a class="hide-sm" href="https://github.com/andrewkamphey/WheresMyMouse">GitHub</a>
      <a class="dl" href="https://wheresmymouse.com/download">Download</a>
    </div>
  </nav>
  <header class="rc-hero">
    <h1>Cursor Recipes</h1>
    <p>{len(RECIPES)} ready-made pointer looks. Open Where's My Mouse? in the menu bar, set the size, pick the fill and outline, and save it as a preset. Click any size to try it bigger or smaller.</p>
    <p class="fine">Colors need macOS 12 or later. Sizes above 15× need Extra large turned on.</p>
  </header>
  <main id="rc-page">
    <div class="rc-bar">
      <div class="rc-seg" role="group" aria-label="Category">{filters}</div>
      <div class="rc-push">
        <div class="rc-seg" role="group" aria-label="Background">{seg("bg", [("split", "◐ Split"), ("light", "☀ Light"), ("dark", "☾ Dark")], "split")}</div>
        <div class="rc-seg" role="group" aria-label="View">{seg("view", [("cards", "Cards"), ("list", "List")], "cards")}</div>
      </div>
    </div>
    <div class="rc-grid" id="rc-grid">
{"".join("      " + card(r) + chr(10) for r in RECIPES)}    </div>
    <div class="rc-list" id="rc-list" hidden>
{"".join("      " + row(r) + chr(10) for r in RECIPES)}    </div>
  </main>
</div>
{footer}
<script src="assets/recipes.js"></script>
<script>
  document.addEventListener('click', function (e) {{
    var a = e.target.closest && e.target.closest('a[href*="/download"]');
    if (a && window.gtag) gtag('event', 'download', {{ file_name: 'WheresMyMouse.dmg', link_url: a.href, transport_type: 'beacon' }});
  }});
</script>
</body>
</html>
'''

index_path = SITE / "index.html"
index = index_path.read_text()
start, end = "<!-- recipes:start -->", "<!-- recipes:end -->"
a, b = index.index(start) + len(start), index.index(end)
index = index[:a] + "\n" + home() + "\n" + index[b:]
index_path.write_text(index)
(SITE / "recipes.html").write_text(page(index))
print(f"{len(RECIPES)} recipes -> site/recipes.html and the home page section")
