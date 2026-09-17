"""Builds the design renders. Every measurement comes from the same tokens the SwiftUI build uses."""

ICONS = {
 'today':'<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>',
 'people':'<svg viewBox="0 0 24 24"><circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c0-3.5 3-6 6.5-6s6.5 2.5 6.5 6"/><circle cx="17" cy="9" r="2.5"/><path d="M15.5 14.5c3 0 6 2 6 5.5"/></svg>',
 'timeline':'<svg viewBox="0 0 24 24"><path d="M4 4v16M9 6h11M9 12h8M9 18h11"/><circle cx="4" cy="12" r="1.6"/></svg>',
 'you':'<svg viewBox="0 0 24 24"><path d="M12 2l8 4.5v9L12 20l-8-4.5v-9z"/><circle cx="12" cy="11.5" r="3"/></svg>',
}
PAW = '<svg width="{s}" height="{s}" viewBox="0 0 24 24" fill="#fff"><ellipse cx="6" cy="9" rx="2.2" ry="3"/><ellipse cx="18" cy="9" rx="2.2" ry="3"/><ellipse cx="9.5" cy="4.5" rx="2.2" ry="3"/><ellipse cx="14.5" cy="4.5" rx="2.2" ry="3"/><path d="M12 10c-4 0-7 3.5-7 6.5C5 19 7 21 9 21c1.2 0 2-.6 3-.6s1.8.6 3 .6c2 0 4-2 4-4.5 0-3-3-6.5-7-6.5z"/></svg>'

def statusbar():
    return ('<div class="statusbar"><span>9:41</span>'
            '<span class="icons"><i class="sig"></i><i class="wifi"></i><i class="batt"></i></span></div>')

def mesh(a1, a2):
    return f'<div class="mesh" style="--a1:{a1};--a2:{a2}"><i class="a"></i><i class="b"></i><i class="c"></i></div>'

def tab(active, badge=None):
    out = '<div class="fade"></div><div class="tab">'
    for key, label in [('today','Today'),('people','People'),('timeline','Timeline'),('you','You')]:
        dot = '<i class="badge"></i>' if badge == key and key != active else ''
        out += f'<span class="{"on" if key == active else ""}">{ICONS[key]}{label}{dot}</span>'
    return out + '</div>'

def phone(name, inner, a1, a2, active=None, night=False, chrome=True, badge=None, wash=None, dim=None):
    bar = tab(active, badge) if chrome else ''
    # The wash is a screen layer, not a header background: it starts at the physical top edge so there is
    # no seam where the person's header begins.
    w = f'<div class="wash" style="background:linear-gradient(180deg,{wash[0]},{wash[1]} 42%,transparent)"></div>' if wash else ''
    d = dim or ''
    return (f'<div class="phone {"night" if night else ""}" data-name="{name}">{mesh(a1, a2)}{w}{d}'
            f'<div class="content">{statusbar()}{inner}</div>{bar}<div class="home"></div></div>')

def sheet_over(backdrop, body):
    """A sheet at a detent: the screen it came from stays visible and dimmed behind it, and the sheet
    is only as tall as its content. Drawing these full bleed is what left half a screen of dead space."""
    return f'{backdrop}<div class="dim"></div><div class="detent">{body}</div>'


def orb(aura, text, size='', pet=False):
    px = {'':46, 's':34, 'h':58, 'i':24, 'x':72}[size]
    inner = PAW.format(s=int(px * 0.4)) if pet else text
    cls = f'orb {aura}' + (f' orb-{size}' if size else '')
    return f'<div class="{cls}">{inner}</div>'

def orb_wrap(aura, text, size='', pet=False, selected=False, dot=False):
    wrap = 'orb-wrap' + (f' wrap-{size}' if size else '') + (' sel' if selected else '')
    return f'<div class="{wrap}">{orb(aura, text, size, pet)}{"<i class=dot></i>" if dot else ""}</div>'

def rail(items, labels=True, add=True, selected=None):
    """items: (aura, initials, name, pet, attention)"""
    out = '<div class="rail">'
    for aura, initials, name, pet, attn in items:
        on = ' on' if name == selected else ''
        lbl = f'<span class="lbl">{name}</span>' if labels else ''
        out += (f'<div class="rail-item{on}">'
                f'{orb_wrap(aura, initials, pet=pet, selected=name == selected, dot=attn)}{lbl}</div>')
    if add:
        lbl = '<span class="lbl">Add</span>' if labels else ''
        out += f'<div class="rail-item"><div class="orb-wrap"><div class="orb add">+</div></div>{lbl}</div>'
    return out + '</div>'

def strip(values, height=20):
    out = f'<div class="strip" style="height:{height}px">'
    for v in values:
        if v is None:
            out += f'<i class="n" style="height:{max(5, height * 0.16):.0f}px"></i>'
            continue
        cls = 'l' if v <= 2 else ('m' if v == 3 else '')
        ratio = 0.34 + (v - 1) / 4 * 0.66
        out += f'<i class="{cls}" style="height:{height * ratio:.0f}px"></i>'
    return out + '</div>'

def ring(pct, size=44, lw=6, color='var(--sky)', label=None, label_size=11):
    # label='' draws the ring with an empty centre, so the track shows through instead of a blank disc.
    # Printing the same percentage twice, once inside the ring and once beside it, is the fastest way to
    # make a dashboard look careless.
    bare = label == ''
    label = f'{pct}%' if label is None else label
    if bare:
        # A real hole, masked out of the ring, so whatever surface is behind shows through.
        return (f'<div class="ring bare" style="width:{size}px;height:{size}px;--lw:{lw}px;'
                f'background:conic-gradient({color} 0 {pct}%,var(--chip) {pct}% 100%)"></div>')
    return (f'<div class="ring" style="width:{size}px;height:{size}px;'
            f'background:conic-gradient({color} 0 {pct}%,var(--chip) {pct}% 100%)">'
            f'<b style="width:{size - lw * 2}px;height:{size - lw * 2}px;font-size:{label_size}px">{label}</b></div>')

def tile(title, value, detail, aura=None, symbol_color='var(--violet)', attn=False,
         warn=False, progress=None, trail=None):
    dot = (f'<i class="adot" style="background:{aura}"></i>' if aura
           else f'<i class="adot" style="background:{symbol_color}"></i>')
    warn_html = '<i class="warn"></i>' if warn else ''
    ring_html = ring(progress, 44, 6, symbol_color, label='') if progress else ''
    trail_html = f'<div style="margin-top:2px">{strip(trail)}</div>' if trail else ''
    # CareType.tileValue keeps one line and scales down to 0.65 rather than truncating, so a long state
    # word still reads. CSS has no minimumScaleFactor, so the generator computes the same fit here.
    fit = max(0.65, min(1.0, 14 / max(1, len(value))))
    vstyle = f'font-size:{19 * fit:.1f}px' if fit < 1 else ''
    return f'''<div class="s s-tile tile">
      <div class="lrow">{dot}<span class="t-label">{title}</span>{warn_html}</div>
      <div class="vrow"><div style="min-width:0">
        <div class="t-tile{' attn' if attn else ''}" style="{vstyle}">{value}</div>
        <div class="t-caption" style="margin-top:3px">{detail}</div>
      </div>{ring_html}</div>{trail_html}</div>'''

def section(title, body, trailing=None):
    tr = f'<span class="t-meta">{trailing}</span>' if trailing else ''
    return f'<div><div class="sec-label"><span class="t-label-e">{title}</span>{tr}</div>{body}</div>'

def title(eyebrow, lead, accent=None, role='screen'):
    # One element, always. Returning two siblings let a parent's section gap open up between the eyebrow
    # and the title it belongs to, which is why one screen's header sat apart from the rest.
    eb = f'<div class="t-label-e">{eyebrow}</div>' if eyebrow else ''
    ac = f'<span class="t-accent" style="font-size:{"36" if role == "screen" else "30"}px"> {accent}</span>' if accent else ''
    return f'<div class="title">{eb}<div class="t-{role}" style="margin-top:3px">{lead}{ac}</div></div>'

def pulse(index=3):
    stops = ''.join(f'<i style="left:calc({p}% - 2.5px)"></i>' for p in (10, 30, 50, 70, 90))
    emoji = ['😞','😕','😐','🙂','😄'][index]
    left = 5 + (index / 4) * (362 - 41)
    words = ['Low','Meh','Okay','Good','Great']
    labels = ''.join(f'<span class="{"on" if i == index else ""}">{w}</span>' for i, w in enumerate(words))
    return (f'<div class="pulse">{stops}<div class="knob" style="left:{left:.0f}px">{emoji}</div></div>'
            f'<div class="pulse-labels">{labels}</div>')

def crow(glyph, tint, title_, sub, right=''):
    return (f'<div class="s s-row row">{gtile(glyph, tint)}'
            f'<div class="sp"><div class="t-body-e clip1">{title_}</div>'
            f'<div class="t-caption clip1">{sub}</div></div>{right}</div>')

def ai_header(label, meta, refresh=True):
    r = f'<div class="iconbtn sm">{G["refresh"]}</div>' if refresh else ''
    return (f'<div class="row b" style="margin-bottom:10px">'
            f'<span class="t-label-e ai-mark" style="color:var(--violet)">{G["sparkle"]}{label}</span>'
            f'<span class="sp"></span><span class="t-meta">{meta}</span>{r}</div>')

def gl(path, fill=False, box=24, sw=2):
    """A line glyph drawn the way SF Symbols are: one weight, round caps, no fill unless asked."""
    style = (f'fill="currentColor" stroke="none"' if fill
             else f'fill="none" stroke="currentColor" stroke-width="{sw}" '
                   f'stroke-linecap="round" stroke-linejoin="round"')
    return f'<svg class="gl" viewBox="0 0 {box} {box}" {style}>{path}</svg>'

# Module and row glyphs. Shaped after the SF Symbols the app asks for, so the renders and the build agree.
G = {
 'pill':      gl('<rect x="2.6" y="8.4" width="18.8" height="7.2" rx="3.6"/><path d="M12 8.4v7.2"/>'),
 'bag':       gl('<path d="M5 8h14l-1 12H6L5 8z"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/>'),
 'drop':      gl('<path d="M12 3.5c3.2 4 5.5 6.6 5.5 9.4A5.5 5.5 0 0 1 12 18.4a5.5 5.5 0 0 1-5.5-5.5c0-2.8 2.3-5.4 5.5-9.4z"/>'),
 'steth':     gl('<path d="M6 3v5a4 4 0 0 0 8 0V3"/><path d="M10 12v2a4.5 4.5 0 0 0 9 0v-1.5"/>'
                 '<circle cx="19" cy="9.5" r="2.2"/><circle cx="6" cy="3" r="1"/><circle cx="14" cy="3" r="1"/>'),
 'scissors':  gl('<circle cx="6.5" cy="17.5" r="2.5"/><circle cx="17.5" cy="17.5" r="2.5"/>'
                 '<path d="M8.4 15.6 18 4M15.6 15.6 6 4"/>'),
 'bug':       gl('<rect x="7.5" y="7" width="9" height="12" rx="4.5"/><path d="M7.5 11H4M16.5 11H20M7.5 15H4.5M16.5 15h3M9 6.5 7.5 4M15 6.5 16.5 4"/>'),
 'face':      gl('<circle cx="12" cy="12" r="8.6"/><path d="M8.6 14.4a4.6 4.6 0 0 0 6.8 0"/>'
                 '<circle cx="9.2" cy="10" r="1" fill="currentColor" stroke="none"/>'
                 '<circle cx="14.8" cy="10" r="1" fill="currentColor" stroke="none"/>'),
 'heart':     gl('<path d="M12 20s-7.4-4.6-7.4-9.6A4.2 4.2 0 0 1 12 7.6a4.2 4.2 0 0 1 7.4 2.8C19.4 15.4 12 20 12 20z"/>'),
 'moon':      gl('<path d="M19.4 14.2A8 8 0 0 1 9.8 4.6a8 8 0 1 0 9.6 9.6z"/>'),
 'calendar':  gl('<rect x="3.6" y="5.4" width="16.8" height="15" rx="3.4"/><path d="M3.6 10h16.8M8.4 3.4v3.6M15.6 3.4v3.6"/>'),
 'gift':      gl('<rect x="3.4" y="9.4" width="17.2" height="11" rx="2.6"/><path d="M3.4 13.6h17.2M12 9.4v11"/>'
                 '<path d="M12 9.4S10.8 4.6 8.6 4.6a2.4 2.4 0 0 0 0 4.8zM12 9.4s1.2-4.8 3.4-4.8a2.4 2.4 0 0 1 0 4.8z"/>'),
 'cake':      gl('<path d="M4 20.4h16M4.8 20.4v-6a2.6 2.6 0 0 1 2.6-2.6h9.2a2.6 2.6 0 0 1 2.6 2.6v6"/>'
                 '<path d="M12 11.8V8.4M12 5.6V4"/>'),
 'phone':     gl('<path d="M7.6 3.8 10 4.4l1.2 3.8-2 1.6a10.6 10.6 0 0 0 5 5l1.6-2 3.8 1.2.6 2.4a2 2 0 0 1-2 2.4A15.6 15.6 0 0 1 5.2 5.8a2 2 0 0 1 2.4-2z"/>'),
 'paw':       gl('<ellipse cx="6.4" cy="9.6" rx="1.9" ry="2.6"/><ellipse cx="17.6" cy="9.6" rx="1.9" ry="2.6"/>'
                 '<ellipse cx="9.8" cy="5.6" rx="1.9" ry="2.6"/><ellipse cx="14.2" cy="5.6" rx="1.9" ry="2.6"/>'
                 '<path d="M12 11.6c-3.4 0-6 3-6 5.6 0 2.1 1.7 3.6 3.4 3.6 1 0 1.7-.5 2.6-.5s1.6.5 2.6.5c1.7 0 3.4-1.5 3.4-3.6 0-2.6-2.6-5.6-6-5.6z"/>', fill=True),
 'mic':       gl('<rect x="9" y="3" width="6" height="10.4" rx="3"/><path d="M5.6 11.6a6.4 6.4 0 0 0 12.8 0M12 18v3"/>'),
 'bolt':      gl('<path d="M13.4 2.6 5.6 13.4h5L10 21.4l8.2-11h-5.2z"/>'),
 'close':     gl('<path d="M6.6 6.6 17.4 17.4M17.4 6.6 6.6 17.4"/>', sw=2.4),
 'refresh':   gl('<path d="M19.6 12a7.6 7.6 0 1 1-2.3-5.4"/><path d="M19.8 4.4v4.4h-4.4"/>', sw=2.2),
 'up':        gl('<path d="M7 17 17 7M9.4 7H17v7.6"/>', sw=2.6),
 'chevron':   gl('<path d="M9.4 5.6 16 12l-6.6 6.4"/>', sw=2.4),
 'arrow':     gl('<path d="M4.6 12h14M13 6.4 18.6 12 13 17.6"/>', sw=2.3),
 'check':     gl('<path d="M5 12.8 9.8 17.4 19 6.6"/>', sw=2.6),
 'plus':      gl('<path d="M12 5.4v13.2M5.4 12h13.2"/>', sw=2.4),
 'thumbup':   gl('<path d="M7.4 10.6 11 3.6a2.2 2.2 0 0 1 3 2v3.4h4a2 2 0 0 1 2 2.3l-1 5.4a2.4 2.4 0 0 1-2.4 2H7.4z"/><rect x="2.8" y="10.6" width="4.6" height="8.1" rx="1.4"/>'),
 'thumbdown': gl('<path d="M16.6 13.4 13 20.4a2.2 2.2 0 0 1-3-2V15H6a2 2 0 0 1-2-2.3l1-5.4a2.4 2.4 0 0 1 2.4-2h9.2z"/><rect x="16.6" y="5.3" width="4.6" height="8.1" rx="1.4"/>'),
 'sparkle':   gl('<path d="M12 1.8c.7 5.4 4.8 9.5 10.2 10.2-5.4.7-9.5 4.8-10.2 10.2-.7-5.4-4.8-9.5-10.2-10.2C7.2 11.3 11.3 7.2 12 1.8z"/>', fill=True),
 'grid':      gl('<rect x="3.8" y="3.8" width="7" height="7" rx="2.2"/><rect x="13.2" y="3.8" width="7" height="7" rx="2.2"/>'
                 '<rect x="3.8" y="13.2" width="7" height="7" rx="2.2"/><rect x="13.2" y="13.2" width="7" height="7" rx="2.2"/>'),
}

def gtile(key, tint):
    """A glyph in its rounded tint square, the way a module reads in a list."""
    return (f'<span class="gtile" style="color:{tint};'
            f'background:color-mix(in srgb,{tint} 13%,transparent)">{G[key]}</span>')


PEOPLE = [
    ('a-coral', 'S', 'Srivalli', False, False),
    ('a-sky', 'R', 'Ramarao', False, True),
    ('a-amber', 'KA', 'Kasi', False, True),
    ('a-violet', 'N', 'Neeraj', False, False),
    ('a-honey', '', 'Oreo', True, False),
]
ALL_PEOPLE = [('a-ink', 'PS', 'Surya', False, False)] + PEOPLE

screens = []

# 01 Today ---------------------------------------------------------------
today = f'''
<div class="gutter stack sec" style="padding-top:8px">
  <div class="row b">
    <div class="sp">{title("Thursday, 17 September", "Good morning,", "Surya")}</div>
    {orb_wrap("a-ink", "PS", size="s")}
  </div>
  <div class="s s-attn stack" style="gap:8px">
    <div class="row base"><i class="adot" style="width:9px;height:9px;border-radius:50%;background:linear-gradient(135deg,#38BDF8,#8B5CF6)"></i>
      <span class="t-label-e" style="color:var(--coral)">Ramarao. Missed dose</span><span class="sp"></span><span class="t-meta">8:00 am</span></div>
    <div class="t-hero-num" style="margin:2px 0">1<span style="font-family:Bricolage;font-weight:700;font-size:22px;letter-spacing:-.3px;color:var(--text-2);margin-left:6px">dose</span></div>
    <div class="t-callout">Telmisartan at 8:00 am, not marked.</div>
    <div class="row" style="gap:8px;margin-top:2px"><span class="pill sm">Mark taken</span><span class="pill sm ghost">Call Ramarao</span></div>
  </div>
</div>
{rail(PEOPLE)}
<div class="gutter stack sec" style="margin-top:26px">
  {section("Also today", f"""<div class="bento">
    {tile("Kasi · Medication", "Due now", "Amlodipine 5 mg, 9:00 am", aura="linear-gradient(135deg,#FFB347,#FF6B57)", symbol_color="var(--coral)", progress=0)}
    {tile("Srivalli · Events", "7:30 pm", "Dinner, just us", aura="linear-gradient(135deg,#FF6B57,#FF4F8B)")}
    {tile("Oreo · Pet care", "4d", "Food order, runs out", aura="linear-gradient(135deg,#F5C453,#34D399)", warn=True, attn=True)}
    {tile("Kasi · Call rhythm", "Every Sunday", "Last call 9d ago", aura="linear-gradient(135deg,#FFB347,#FF6B57)")}
  </div>""")}
  <div class="s s-ai">
    {ai_header("Insight", "on device · just now")}
    <div class="t-card" style="margin-bottom:10px">2 people need a moment today</div>
    <div class="stats" style="margin-bottom:10px">
      <div class="stat"><div class="t-caption">Needs you</div><div class="v attn">2</div></div>
      <div class="stat"><div class="t-caption">People</div><div class="v">5</div></div>
    </div>
    <div class="t-label" style="margin-bottom:4px">Today, in order</div>
    <ul class="list"><li>Ramarao. Missed dose</li><li>Kasi. 9 days since a call</li><li>Kasi. Amlodipine</li></ul>
  </div>
</div>'''
screens.append(phone('01-today', today, '#38BDF8', '#8B5CF6', active='today', badge='people'))
# Sheets are drawn over the screen they were opened from, so they read as a detent and not a new page.
today_backdrop = today + tab('today', 'people')

# 02 Person: Srivalli ----------------------------------------------------
srivalli = f'''
{rail(ALL_PEOPLE, labels=False, add=True, selected="Srivalli")}
<div style="margin-top:4px">
  <div class="gutter stack sec" style="padding-top:8px">
    <div>
      <div class="row">{orb_wrap("a-coral", "S", size="h")}
        <div class="sp"><div class="t-label-e">Partner · Married 26 August 2026</div>
          <div class="t-screen" style="font-size:36px;margin-top:1px">Srivalli</div></div></div>
      <div class="t-callout" style="margin-top:8px">Dinner at 7:30. Just the two of you, so leave work on time.</div>
    </div>
    <div class="s s-card">
      <div class="row b" style="margin-bottom:12px"><span class="t-label-e">How is Srivalli today?</span><span class="t-meta">last 12h ago</span></div>
      {pulse(3)}
      <div style="margin-top:12px"><span class="pill sm ghost">Save good</span></div>
    </div>
    {section("Modules", f"""<div class="bento">
      {tile("Mood", "Good", "Checked in 12h ago", symbol_color="var(--mint)", trail=[4,4,4,2,4,4,5,4,4,4,2,4,4,5])}
      {tile("Health", "Neutral", "back pain, day 2", symbol_color="var(--mint)")}
      {tile("Mentions", "Weekend in the hills", "6 notes · want", symbol_color="var(--violet)")}
      {tile("Milestones and dates", "18d", "First date · the 2nd", symbol_color="var(--amber)")}
      {tile("Shared checklist", "3 open", "Curtains, dentist, gift", symbol_color="var(--violet)")}
      <div class="tile-add"><span style="font-size:17px;font-weight:600">+</span><span class="t-label">Add a module</span></div>
    </div>""", trailing="9 on")}
    <div class="s s-ai">{ai_header("Insight · 30 days", "on device · 2h ago")}
      <div class="t-card">A good month with a Wednesday dip</div></div>
  </div>
</div>'''
screens.append(phone('02-person-srivalli', srivalli, '#FF6B57', '#FF4F8B', active='people',
                     wash=('rgba(255,107,87,.34)', 'rgba(255,79,139,.14)')))
person_backdrop = srivalli + tab('people')

# 03 Person: Ramarao -----------------------------------------------------
ramarao = f'''
{rail(ALL_PEOPLE, labels=False, add=True, selected="Ramarao")}
<div style="margin-top:4px">
  <div class="gutter stack sec" style="padding-top:8px">
    <div>
      <div class="row">{orb_wrap("a-sky", "R", size="h", dot=True)}
        <div class="sp"><div class="t-label-e">Parent · BP patient, pre-diabetic</div>
          <div class="t-screen" style="font-size:36px;margin-top:1px">Ramarao</div></div></div>
      <div class="t-callout" style="margin-top:8px">Telmisartan at 8:00 am, not marked.</div>
    </div>
    {section("Modules", f"""<div class="bento">
      {tile("Medication", "0 of 3", "Missed Telmisartan 8:00 am", symbol_color="var(--coral)", attn=True, warn=True, progress=0)}
      {tile("Health", "138/90", "BP · 7:45 am", symbol_color="var(--coral)", attn=True, warn=True)}
      {tile("Appointments", "7d", "Dr. Iyer · 3 questions", symbol_color="var(--coral)")}
      {tile("Call rhythm", "Every Wednesday", "Last call 1d ago", symbol_color="var(--violet)")}
      {tile("Milestones and dates", "115d", "Dad's birthday", symbol_color="var(--amber)")}
      {tile("Mentions", "Missing his walk", "2 notes · worry", symbol_color="var(--violet)")}
    </div>""", trailing="6 on")}
    <div class="s s-ai">
      {ai_header("Insight · 30 days", "on device · 6h ago")}
      <div class="t-card" style="margin-bottom:10px">2 of 7 readings above the usual range</div>
      <div class="stats" style="margin-bottom:10px">
        <div class="stat"><div class="t-caption">Above range</div><div class="v attn">2 of 7</div></div>
        <div class="stat"><div class="t-caption">Doses, 14 days</div><div class="v good">90%</div></div>
      </div>
      <div class="row top" style="gap:8px"><span class="gl-inline" style="color:var(--violet);padding-top:3px">{G["sparkle"]}</span>
        <span class="t-callout" style="color:var(--text)">Most missed doses fall on Wednesdays. A reminder to whoever is around that day helps.</span></div>
    </div>
  </div>
</div>'''
screens.append(phone('03-person-ramarao', ramarao, '#38BDF8', '#8B5CF6', active='people',
                     wash=('rgba(56,189,248,.34)', 'rgba(139,92,246,.14)')))

# 04 Medication ----------------------------------------------------------
dose_actions = '<div class="row" style="gap:6px"><span class="pill sm">Taken</span><span class="pill sm ghost">Skip</span></div>'
med = f'''
<div class="gutter stack sec" style="padding-top:8px">
  <div class="row top">
    <div class="sp"><div class="row" style="gap:6px">{orb_wrap("a-sky", "R", size="i")}
      <span class="t-label-e">Ramarao · Medication</span></div>
      <div class="t-screen" style="color:var(--coral);margin-top:4px">0 of 3</div>
      <div class="t-callout" style="margin-top:2px">Missed Telmisartan 8:00 am</div></div>
    {ring(0, 64, 8, "var(--coral)", label="")}
  </div>
  {section("Today", f"""<div class="stack row-gap" style="gap:8px">
    {crow("pill", "var(--coral)", "Telmisartan, 40 mg", "8:00 am", dose_actions)}
    {crow("pill", "var(--muted)", "Amlodipine, 5 mg", "8:00 pm · Mom gives it", dose_actions)}
    {crow("pill", "var(--muted)", "Metformin, 500 mg", "8:30 pm · with food", dose_actions)}
  </div>""")}
  <div class="bento">
    <div class="s s-tile row" style="gap:12px;min-height:0">{ring(95, 52, 7, "var(--mint)", label="")}
      <div><div class="t-tile">95%</div><div class="t-caption">taken, 7 days</div></div></div>
    <div class="s s-tile row" style="gap:12px;min-height:0">{ring(90, 52, 7, "var(--mint)", label="")}
      <div><div class="t-tile">90%</div><div class="t-caption">taken, 30 days</div></div></div>
  </div>
  {section("Medicines", f"""<div class="stack row-gap" style="gap:8px">
    {crow("pill", "var(--coral)", "Telmisartan · 40 mg", "8:00 am · Blood pressure · refill in 22 days")}
    {crow("pill", "var(--coral)", "Amlodipine · 5 mg", "8:00 pm · Blood pressure", '<span class="t-meta" style="color:var(--amber)">refill 4d</span>')}
    {crow("pill", "var(--coral)", "Metformin · 500 mg", "8:30 pm · Blood sugar · refill in 15 days")}
  </div>""", trailing="3")}
</div>
<div class="actionbar"><span class="pill">{G["plus"]}Add a medicine</span></div>'''
screens.append(phone('04-medication-ramarao', med, '#38BDF8', '#8B5CF6', active='people', badge='people',
                     wash=('rgba(56,189,248,.30)', 'rgba(139,92,246,.12)')))

# 05 Timeline ------------------------------------------------------------
def tl_row(time, colour, name, sub, tag='', attn=False, done=False):
    badge = '<span style="color:var(--mint);font-size:18px">✓</span>' if done else (
        f'<span class="tag {"attn" if attn else ""}">{tag}</span>' if tag else '')
    return (f'<div class="t">{time}</div><div class="rail-col"><b style="background:{colour}"></b></div>'
            f'<div class="s s-row it"><div class="sp"><div class="t-body-e clip1">{name}</div>'
            f'<div class="t-caption clip1">{sub}</div></div>{badge}</div>')

days = ''.join(
    f'<div class="day {"on" if d == 17 else ""} {"today" if d == 17 else ""}">'
    f'<span class="w">{w}</span><span class="d">{d}</span>'
    f'<span class="dot" style="{"" if d in (17,18,21,24) else "background:transparent"}"></span></div>'
    for w, d in [("M",15),("T",16),("W",17),("T",18),("F",19),("S",20),("S",21),("M",22)])

timeline = f'''
<div class="gutter" style="padding-top:8px">
  <div class="row b" style="align-items:flex-end">
    <div class="sp">{title("Timeline", "Today")}</div>
    <div class="seg"><span class="on">Day</span><span>Week</span></div>
  </div>
</div>
<div class="days" style="margin-top:26px">{days}</div>
<div class="gutter" style="margin-top:26px">
  <div class="tl">
    {tl_row("8:00 am", "linear-gradient(135deg,#38BDF8,#8B5CF6)", "Telmisartan, 40 mg", "Ramarao · Missed", "Missed", attn=True)}
    {tl_row("9:00 am", "linear-gradient(135deg,#FFB347,#FF6B57)", "Amlodipine, 5 mg", "Kasi · Medication")}
    <div class="nowline"><div class="t">9:41 am</div><b></b><hr></div>
    {tl_row("1:00 pm", "linear-gradient(135deg,#15131C,#5C5A6B)", "Water check", "0.5 L of 3 L. Tap to add")}
    {tl_row("7:30 pm", "linear-gradient(135deg,#FF6B57,#FF4F8B)", "Dinner, just us", "Srivalli · Social", "Calendar")}
    {tl_row("8:00 pm", "linear-gradient(135deg,#38BDF8,#8B5CF6)", "Amlodipine, 5 mg", "Ramarao · Medication")}
    {tl_row("8:30 pm", "linear-gradient(135deg,#38BDF8,#8B5CF6)", "Metformin, 500 mg", "Ramarao · Medication")}
    {tl_row("9:00 pm", "linear-gradient(135deg,#15131C,#5C5A6B)", "Evening wrap", "3 questions")}
  </div>
  <div class="t-foot" style="padding:0 4px;margin-top:14px">Apple Calendar and Reminders merge into this rail in Phase 1.</div>
</div>'''
screens.append(phone('05-timeline', timeline, '#15131C', '#5C5A6B', active='timeline', badge='people'))

# 06 Quick sheet ---------------------------------------------------------
quick_body = f'''
<div class="grabber"></div>
<div class="gutter stack row-gap" style="padding-top:22px">
  <div class="row">{orb_wrap("a-coral", "S")}
    <div class="sp"><div class="t-label-e">Quick check-in</div>
      <div class="t-sheet" style="margin-top:1px">How is Srivalli today?</div></div>
    <div class="iconbtn">{G["close"]}</div></div>
  <div class="s s-card" style="padding:14px">
    <div class="sec-label"><span class="t-label-e">Mood</span></div>{pulse(3)}</div>
  <div class="s s-card" style="padding:14px">
    <div class="sec-label"><span class="t-label-e">Health</span><span class="t-meta">private to you</span></div>
    <div class="chips" style="margin-bottom:8px"><span class="chip">All good</span><span class="chip on">Neutral</span><span class="chip">Not good</span></div>
    <div class="chips"><span class="chip">Headache</span><span class="chip on">Back pain</span><span class="chip">Tired</span><span class="chip">Cold</span></div></div>
  <div class="s s-card" style="padding:14px">
    <div class="sec-label"><span class="t-label-e">Something they said</span></div>
    <div class="s s-field row"><span class="sp t-body" style="color:var(--muted)">Wants to try the pottery class…</span>
      <span style="color:var(--muted);display:grid;place-items:center">{G["mic"]}</span></div></div>
  <div style="padding-bottom:6px"><span class="pill">Done</span></div>
</div>'''
quick = sheet_over(today_backdrop, quick_body)
screens.append(phone('06-quick-sheet', quick, '#FF6B57', '#FF4F8B', chrome=False))

# 07 Insight, night ------------------------------------------------------
night = f'''
{rail(ALL_PEOPLE, labels=False, add=False, selected="Srivalli")}
<div class="gutter stack row-gap" style="padding-top:12px">
  <div class="row">{orb_wrap("a-coral", "S")}
    <div class="sp"><div class="t-label-e">Partner</div><div class="t-sheet" style="margin-top:1px">Srivalli</div></div></div>
  <div class="s s-ai stack row-gap">
    {ai_header("Insight · 30 days", "refreshed 6h ago")}
    <div class="t-card" style="font-size:22px">A good month with a Wednesday dip</div>
    <div class="stats">
      <div class="stat"><div class="t-caption">Check-ins</div><div class="v">30<span class="gl-inline up">{G["up"]}</span></div></div>
      <div class="stat"><div class="t-caption">Good or better</div><div class="v good">70%<span class="gl-inline up">{G["up"]}</span></div></div>
      <div class="stat"><div class="t-caption">Low days</div><div class="v attn">5</div></div>
    </div>
    <div class="panel"><div class="t-label" style="margin-bottom:6px">Mood, 14 days</div>{strip([4,4,4,2,4,4,5,4,4,4,2,4,4,5], 30)}</div>
    <div class="row top" style="gap:8px"><span class="gl-inline" style="color:var(--violet);padding-top:3px">{G["sparkle"]}</span>
      <span class="t-callout" style="color:var(--text)">Wednesdays average 2.0 out of 5, the lowest weekday. Worth a lighter Wednesday.</span></div>
    <div><div class="t-label" style="margin-bottom:4px">Things Srivalli mentioned wanting</div>
      <ul class="list"><li>The pottery class in Jubilee Hills</li><li>Looked it up twice this month</li><li>A weekend in the hills before winter</li></ul></div>
    <div class="panel row b"><div><div class="t-label">First date</div>
      <div class="t-num" style="margin-top:2px">18<span style="font-size:15px;color:var(--text-2)">d</span></div></div>
      <span class="t-meta" style="align-self:flex-end">Monday 5 Oct</span></div>
    <div class="action"><div><div class="t-body-e">Plan the day</div>
      <div class="t-caption" style="color:rgba(255,255,255,.66)">5 wishlist items, 18 days to go</div></div>
      <span class="gl-inline">{G["arrow"]}</span></div>
    <div class="row b" style="gap:10px"><span class="t-foot sp">Based on 30 check-ins, 6 mentions, 2 events.</span>
      <span class="row" style="gap:2px"><span class="iconbtn sm">{G["thumbup"]}</span>
      <span class="iconbtn sm">{G["thumbdown"]}</span></span></div>
  </div>
</div>'''
screens.append(phone('07-insight-night', night, '#FF6B57', '#8B5CF6', active='people', night=True,
                     wash=('rgba(255,107,87,.26)', 'rgba(255,79,139,.10)')))
night_backdrop = night + tab('people')

# 08 Module store --------------------------------------------------------
def store_card(glyph, name, tagline, tier, on=None, soon=False, auto=False, suggested=False):
    toggle = (f'<div class="switch {"" if on else "off"}" style="transform:scale(.82);transform-origin:right center"></div>'
              if not soon else '<span class="t-meta">Soon</span>')
    tier_colour = 'var(--mint)' if tier == 'Included' else 'var(--violet)'
    badges = f'<span class="tag" style="color:{tier_colour}">{tier}</span>'
    if auto: badges += '<span class="tag">auto</span>'
    if suggested: badges += '<span class="tag" style="color:var(--amber)">suggested</span>'
    return f'''<div class="s s-tile" style="min-height:158px;display:flex;flex-direction:column;gap:8px;{"opacity:.68" if soon else ""}">
      <div class="row b" style="height:32px">{gtile(glyph, tier_colour if tier == 'Included' else 'var(--violet)')}{toggle}</div>
      <div class="t-body-e clip1">{name}</div>
      <div class="t-caption" style="flex:1">{tagline}</div>
      <div class="tagrow">{badges}</div></div>'''

store_body = f'''
<div class="grabber"></div>
<div class="gutter" style="padding-top:22px">
  <div class="row top"><div class="sp">{title("For Srivalli · 9 on", "Switch on what", "matters", role="sheet")}</div>
    <div class="iconbtn">{G["close"]}</div></div>
</div>
{rail([(a, i, n, p, False) for a, i, n, p, _ in ALL_PEOPLE], labels=True, add=False, selected="Srivalli").replace('orb-wrap', 'orb-wrap wrap-s').replace('class="orb ', 'class="orb orb-s ')}
<div class="gutter stack row-gap" style="margin-top:20px">
  <div class="chips" style="flex-wrap:nowrap;overflow:hidden">
    <span class="chip on">All</span><span class="chip">Wellbeing</span><span class="chip">Moments</span>
    <span class="chip">Together</span><span class="chip">Care</span></div>
  <div class="bento">
    {store_card("face", "Mood", "Five states on the Pulse control, optional reason tag. A 14 day trail on the tile.", "Included", on=True, auto=True)}
    {store_card("heart", "Health", "All good, neutral, not good. Symptom chips, BP and sugar readings.", "Included", on=True)}
    {store_card("drop", "Hydration", "Cup taps and a target ring. Logged for yourself or on behalf of others.", "Included", on=False, auto=True, suggested=True)}
    {store_card("moon", "Sleep and energy", "Self from Apple Health. Observed for others as an energy word.", "Plus", soon=True, auto=True)}
    {store_card("calendar", "Events", "Anything happening in a person's life, in seven categories.", "Included", on=True, auto=True)}
    {store_card("gift", "Wishlist", "Share any product link. Sizes, colours, a please-do-not-buy list.", "Included", on=True, auto=True)}
  </div>
  <div style="height:4px"></div>
</div>'''
store = sheet_over(person_backdrop, store_body)
screens.append(phone('08-module-store', store, '#FF6B57', '#FF4F8B', chrome=False,
                     wash=('rgba(255,107,87,.34)', 'rgba(255,79,139,.14)')))

# 09 You -----------------------------------------------------------------
you = f'''
<div class="gutter stack sec" style="padding-top:8px">
  {title("You", "Your", "settings")}
  <div class="s s-hero row">{orb_wrap("a-ink", "PS", size="h")}
    <div class="sp"><div class="t-card">Paluvadi Surya</div>
      <div class="t-caption" style="margin-top:2px">6 modules on your profile · 5 people in your circle</div></div>
    <span class="gl-inline" style="color:var(--muted)">{G["chevron"]}</span></div>
  <div class="s s-card stack row-gap">
    <div class="row b"><span class="t-label-e ai-mark" style="color:var(--violet)">{G["sparkle"]}Intelligence</span>
      <span class="t-meta" style="color:var(--mint)">OpenAI key saved</span></div>
    <div class="t-foot">Without a key, insights are written on device from your own numbers. Add an OpenAI or DeepSeek key and the model writes them instead. Keys live in the Keychain.</div>
    <div class="chips"><span class="chip on">OpenAI</span><span class="chip">DeepSeek</span></div>
    <div class="row" style="gap:8px"><div class="s s-field sp t-body" style="color:var(--muted)">Replace the saved key</div>
      <span class="pill sm">Save</span></div>
    <div class="bento" style="gap:8px">
      <div><div class="t-label" style="margin-bottom:6px">Daily model</div>
        <div class="s s-field" style="font-family:GeistMono;font-size:14px">gpt-5.6-luna</div></div>
      <div><div class="t-label" style="margin-bottom:6px">Weekly model</div>
        <div class="s s-field" style="font-family:GeistMono;font-size:14px">gpt-5.6-terra</div></div></div>
    <div class="s s-field row b" style="min-height:54px"><div><div class="t-body-e">Use the model</div>
      <div class="t-caption">Off keeps everything on device even with a key</div></div><div class="switch"></div></div>
    <div class="row" style="gap:8px"><span class="pill sm ghost">{G["bolt"]}Test connection</span><span class="pill sm ghost">Remove key</span></div>
    <div class="t-caption" style="color:var(--mint)">OK. OpenAI answered with gpt-5.6-luna.</div>
  </div>
  <div class="s s-card stack row-gap">
    <div class="sec-label" style="margin:0"><span class="t-label-e">Reminders</span><span class="t-meta">7 planned</span></div>
    <div class="s s-field row b"><span class="t-label">Daily cap</span><span class="t-body-e">5 a day</span></div>
    <div class="s s-field row b"><span class="t-label">Morning brief</span><span class="t-body-e">8:00 am</span></div>
  </div>
</div>'''
screens.append(phone('09-you-intelligence', you, '#15131C', '#8B5CF6', active='you', badge='people'))

# 10 Pet care ------------------------------------------------------------
pet = f'''
<div class="gutter stack sec" style="padding-top:8px">
  <div class="row top"><div class="sp"><div class="row" style="gap:6px">{orb_wrap("a-honey", "", size="i", pet=True)}
      <span class="t-label-e">Oreo · Pet care</span></div>
    <div class="t-screen" style="margin-top:4px">4d</div>
    <div class="t-callout" style="margin-top:2px">Food order · food runs out</div></div></div>
  {section("Due next", f"""<div class="stack row-gap" style="gap:8px">
    {crow("bag", "var(--amber)", "Food order", "Royal Canin 3 kg", '<span class="t-meta" style="color:var(--amber)">4d</span>')}
    {crow("bug", "var(--amber)", "Tick treatment", "Bravecto spot-on", '<span class="t-meta">14d</span>')}
    {crow("steth", "var(--coral)", "Vet visit", "Yearly check. Teeth to watch.", '<span class="t-meta">18d</span>')}
    {crow("scissors", "var(--muted)", "Grooming", "Full trim, teddy cut", '<span class="t-meta">27d</span>')}
    {crow("pill", "var(--muted)", "Deworming", "Drontal, half tablet", '<span class="t-meta">28d</span>')}
  </div>""")}
  <div class="s s-card"><div class="sec-label" style="margin-bottom:6px"><span class="t-label-e">Weight</span><span class="t-meta">6.0 kg now</span></div>
    <svg width="330" height="56" viewBox="0 0 330 56"><defs><linearGradient id="wg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#F5C453" stop-opacity=".32"/><stop offset="1" stop-color="#F5C453" stop-opacity="0"/></linearGradient></defs>
      <path d="M4,44 L85,33 L166,27 L247,16 L326,22 L326,56 L4,56 Z" fill="url(#wg)"/>
      <path d="M4,44 L85,33 L166,27 L247,16 L326,22" fill="none" stroke="#F5C453" stroke-width="2" stroke-linecap="round"/>
      <circle cx="326" cy="22" r="3.5" fill="#F5C453"/></svg></div>
  <div class="s s-tile row b"><div><div class="t-body-e">Shih Tzu</div>
    <div class="t-caption">Vet: Dr. Meera, Cessna Lifeline</div>
    <div class="t-caption">Food: Royal Canin, 3 kg, 30 days a bag</div></div><span class="pill sm ghost">Edit</span></div>
</div>
<div class="actionbar"><span class="pill">{G["plus"]}Log care</span></div>'''
screens.append(phone('10-petcare-oreo', pet, '#F5C453', '#34D399', active='people', badge='people',
                     wash=('rgba(245,196,83,.30)', 'rgba(52,211,153,.12)')))

# 11 Evening wrap --------------------------------------------------------
wrap_body = f'''
<div class="grabber"></div>
<div class="gutter stack row-gap" style="padding-top:22px">
  <div class="row top"><div class="sp">{title("Evening wrap", "One minute,", "three questions", role="sheet")}</div>
    <div class="iconbtn">{G["close"]}</div></div>
  <div class="s s-hero stack row-gap">
    <div class="row">{orb_wrap("a-coral", "S")}
      <div class="sp"><div class="t-meta">1 of 3</div><div class="t-card" style="margin-top:1px">How was Srivalli today?</div></div></div>
    {pulse(3)}
    <div class="row" style="gap:8px"><span class="pill">Save</span><span class="pill ghost">Skip</span></div>
  </div>
  <div class="progress" style="padding-bottom:4px"><i class="on"></i><i></i><i></i></div>
</div>'''
wrap = sheet_over(night_backdrop, wrap_body)
screens.append(phone('11-evening-wrap', wrap, '#FF6B57', '#8B5CF6', chrome=False, night=True,
                     wash=('rgba(255,107,87,.22)', 'rgba(139,92,246,.10)')))

# 12 Onboarding ----------------------------------------------------------
def float_card(glyph, aura, name, detail, x, y, rot):
    return (f'<div class="s s-row row" style="position:absolute;left:calc(50% + {x}px);top:{y}px;'
            f'transform:translateX(-50%) rotate({rot}deg);gap:10px;padding:10px;width:196px">'
            f'<span class="gtile" style="background:{aura};color:#fff">{G[glyph]}</span>'
            f'<div class="sp"><div class="t-label-e" style="color:var(--text)">{name}</div>'
            f'<div class="t-caption">{detail}</div></div></div>')

onboarding = f'''
<div style="position:relative;height:280px;margin-top:40px">
  {float_card("face", "linear-gradient(135deg,#FF6B57,#FF4F8B)", "Mood", "Good, 7 day trail", -72, 6, -7)}
  {float_card("pill", "linear-gradient(135deg,#38BDF8,#8B5CF6)", "Medication", "2 of 2 today", 76, 60, 6)}
  {float_card("cake", "linear-gradient(135deg,#FFB347,#FF6B57)", "Anniversary", "in 12 days", -56, 116, 4)}
  {float_card("paw", "linear-gradient(135deg,#F5C453,#34D399)", "Pet care", "vet in 18 days", 82, 170, -5)}
  {float_card("phone", "linear-gradient(135deg,#8B5CF6,#C4B5FD)", "Sunday call", "2 talking points", -14, 222, 1)}
</div>
<div class="gutter stack sec" style="margin-top:20px">
  <div>
    <div class="t-meta">care</div>
    <div class="t-screen" style="font-size:38px;margin-top:10px;line-height:1.05">The people you love,
      <span class="t-accent" style="font-size:42px">finally</span> in one place.</div>
    <div class="t-callout" style="margin-top:12px">Modules for every person. Insights every morning. Ten seconds a day.</div>
  </div>
  <div class="stack" style="gap:8px"><span class="pill">Start on this device</span>
    <span class="pill ghost">Try it with a demo circle</span></div>
  <div class="t-foot">Everything stays on this phone. No account, no cloud. You can bring a model key later.</div>
</div>'''
screens.append(phone('12-onboarding', onboarding, '#FF6B57', '#8B5CF6', chrome=False))

doc = ('<!doctype html><html><head><meta charset="utf-8">'
       '<link rel="stylesheet" href="care.css"></head><body><div class="sheet">'
       + ''.join(screens) + '</div></body></html>')
open('screens.html', 'w').write(doc)
print('screens:', len(screens))
