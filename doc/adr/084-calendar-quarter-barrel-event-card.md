# ADR-084: Calendar Quarter Barrel + Single Event Card

**Status:** Draft (proposed 2026-08-09; awaiting sign-off). **Amended 2026-08-29:** the drum buckets by **month**, not quarter; the palette is **inverted** so time drives the fill and the past recedes to grey; the drum becomes a **true cylinder**; the tile is edge-coded; quiet months render but the drum never rests on one; country flags become the complete circular set; the card gains three surface treatments; a tap on a receded row's panel now carries that panel to the card rather than the row's default; the date leads the card; and the caret is realigned to the widened tiles. Open items 1 and 2 remain open — neither is settled by this amendment.
**Date:** 2026-08-09
**Supersedes:** [ADR-015](015-m8-ui-design-decisions.md) §2 (Calendar Layout — Vertical Timeline) and its `m8_calendar_view.html` mockup registry entry. ADR-015 §§1, 3–9 are untouched.
**Amends:** [ADR-018](018-rolling-score.md) (withdraws the calendar rolling-progress strip; the scoring rule is unaffected), [ADR-017](017-season-configurable-evf-toggle.md) (records the calendar's own toggle field and the data constraint), [ADR-079](079-event-self-registration-identity.md) §7 (decouples the entry-list gate from the registration cutoff), [ADR-030](030-event-registration-url-deadline.md) (relocates the registration DOM contract), [ADR-005](005-svelte-state-i18n.md) (retires the no-pluralisation trade-off), [ADR-028](028-evf-calendar-results-import.md) (carves out one-time curated enrichment), [ADR-037](037-derived-display-status-awaiting-results.md) (repoints consumers), [ADR-040](040-multi-slot-event-urls.md) (permits render-time day labels)
**Relates to:** [ADR-007](007-shadow-dom-deferred.md) (Shadow DOM + CSP on `<spws-calendar>`), [ADR-009](009-cert-prod-runtime-toggle.md) (the env footer this view carries), [ADR-046](046-pew-weapon-suffix.md) (weapon derived from code suffix), [ADR-077](077-event-lifecycle-season-skeletons.md) (`CREATED` hidden until dated), [ADR-063](063-polish-plural-and-grupy-zbiorcze.md) (Polish grammatical case as a first-class concern)
**Amended by:** [ADR-087](087-pzsz-senior-calendar-source.md) (a fifth `PanelType` member `'pzs'` and a fourth registry `'PZSz'`; `registryOf()`'s return union widens from three registries to four, and a fourth hue — desaturated PZSz red `#c05555` — enters the organizer channel of §F. The `RG` map in this ADR's mock, `var RG={ppw:'SPWS',pew:'EVF',int:'FIE'}`, and the proper-noun list in §11 are both extended by one entry. Channel assignments, the palette inversion and every other decision here are untouched.)
**Source:** `doc/plans/kalendarz-barrel-2026-08-08.html` (plan + live acceptance mock), `doc/plans/kalendarz-barrel-adr-alignment-2026-08-09.html` (ADR audit)
**Amended by:** [ADR-089](089-event-weapons-and-card-header.md) (§8's field order changes at the top of the card: row one becomes organizer logo + weapon pills + the SHORT event code, the date takes a full-width row of its own, the registry text chip is replaced by the organizer's mark, and the weapon pills move from the card's foot into the header and read `tbl_event.arr_weapons` rather than the code suffix. The remaining nine blocks are untouched.)

## The decision, as a working screen

The mock below **is** the acceptance criterion for this decision, reproduced here so the ADR stands on its own. It is live: drag the width slider from 320px upward, tap a quarter label or a receded row to rotate the drum, tap a panel to select an event, toggle `PPW` / `+EVF` and `EN | PL`, copy a venue address, and use the season-config checkbox to see the calendar with and without the `+EVF` control.

**Full plan and rationale:** [`doc/plans/kalendarz-barrel-2026-08-08.html`](../plans/kalendarz-barrel-2026-08-08.html) — the phase breakdown, the field contract in its §04, the CERT data analysis and the acceptance procedure. This ADR records *what was decided*; the plan records *how it was built and measured*.

**What in the mock is real, and what is not.** The fixture is **real CERT data** — all 103 non-skeleton events across four seasons, pulled from `vw_calendar` on 8 August 2026. But that fixture carries only seven columns and never held a fee, a deadline or a registration URL. Four values — **entry fee and both weapon tiers, registration deadline, registration link, entry-list link** — are therefore *illustrative*, derived deterministically from the event code so every present/absent combination can be reviewed. Their **presence, placement, formatting and conditional rules are the specification**; their values are not data. Everything else on screen is real.

<div class="adr-live-mock">
<style>
.adr-live-mock{
  --surface-0:#f7f6f3; --surface-1:#f1efe9; --surface-2:#ffffff;
  --text-primary:#1c1b19; --text-secondary:#565550; --text-muted:#8a887f;
  --border:rgba(0,0,0,.13); --border-strong:rgba(0,0,0,.24); --border-stronger:rgba(0,0,0,.42);
  --bg-accent:#E6F1FB; --text-accent:#185FA5; --border-accent:#378ADD;
  --radius:8px; --rule:rgba(0,0,0,.10);
  --sans:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
  --mono:ui-monospace,"SF Mono",Menlo,Consolas,monospace;
  color:var(--text-primary);
}
@media (prefers-color-scheme: dark){
.adr-live-mock{
  --surface-0:#17171a; --surface-1:#1f1f23; --surface-2:#26262b;
  --text-primary:#eceae5; --text-secondary:#a9a79f; --text-muted:#77756d;
  --border:rgba(255,255,255,.14); --border-strong:rgba(255,255,255,.26); --border-stronger:rgba(255,255,255,.44);
  --bg-accent:#0C447C; --text-accent:#B5D4F4; --border-accent:#378ADD;
  --rule:rgba(255,255,255,.12);
}
}
.adr-live-mock *{box-sizing:border-box}
.adr-live-mock .mockwrap{background:var(--surface-1);border-radius:14px;padding:1.6rem 1rem 1.9rem;margin:1.2rem 0 1rem;display:flex;flex-direction:column;align-items:center;gap:1rem}
.adr-live-mock .mockcap{font-family:var(--sans);font-size:12.5px;color:var(--text-muted);text-align:center;margin:0;max-width:46rem}
</style>
<style>
#mkctl{display:flex;align-items:center;gap:12px;width:100%;max-width:440px;font-family:var(--sans)}
#mkctl label{font-size:11px;color:var(--text-secondary);white-space:nowrap}
#mkctl input[type=range]{flex:1}
.cfg{display:flex;align-items:center;gap:10px;width:100%;max-width:440px;font-family:var(--sans);margin-top:8px;flex-wrap:wrap}
.cfg label{display:flex;align-items:center;gap:6px;font-size:11px;color:var(--text-secondary);cursor:pointer}
.cfgn{font-size:10px;color:var(--text-muted)}
.cfgn code{font-size:10px}
.ro{font-size:11px;color:var(--text-primary);min-width:132px;text-align:right}
.ph{border:1px solid var(--border-strong);border-radius:24px;background:var(--surface-2);padding:9px 6px 12px;transition:width .2s;font-family:var(--sans)}
.nub{width:38px;height:4px;border-radius:2px;background:var(--border-strong);margin:0 auto 8px}
.envf{display:flex;justify-content:center;padding:14px 0 2px}
.envt{display:flex;border:1px solid var(--border);border-radius:var(--radius);overflow:hidden}
.envb{font-size:11px;font-weight:600;letter-spacing:.5px;padding:3px 10px;border:none;background:var(--surface-2);color:var(--text-muted);cursor:pointer;font-family:inherit}
.envb+.envb{border-left:1px solid var(--border)}
.envb.on{background:#378ADD;color:#fff}
.hd{display:flex;align-items:center;gap:7px;padding:0 3px 8px;border-bottom:1px solid var(--border)}
.hb{background:none;border:none;padding:0;cursor:pointer;color:var(--text-primary);font-size:15px;line-height:1}
.lgo{height:15px;width:auto;display:block;flex:0 0 auto}
.ttl{font-size:14px;font-weight:600}
.lang{margin-left:auto;display:flex;border:1px solid var(--border);border-radius:var(--radius);overflow:hidden}
.lb{font-size:11px;padding:2px 7px;border:none;background:var(--surface-2);color:var(--text-muted);cursor:pointer;font-family:inherit}
.lb+.lb{border-left:1px solid var(--border)}
.lb.on{background:var(--surface-0);color:var(--text-primary);font-weight:600}
.fil{display:flex;justify-content:center;gap:6px;padding:8px 0 2px}
.seg{display:flex;border:1px solid var(--border);border-radius:var(--radius);overflow:hidden}
.sg,.wb{font-size:11px;font-weight:600;padding:3px 9px;border:none;background:var(--surface-2);cursor:pointer;font-family:inherit}
.sg{color:var(--text-secondary)}
.sg+.sg,.wb+.wb{border-left:1px solid var(--border)}
.sg.on{background:#378ADD;color:#fff}
.wb{color:var(--text-muted)}
.wb.on{background:var(--bg-accent);color:var(--text-accent)}
.wseg{max-width:0;opacity:0;overflow:hidden;transition:max-width .3s,opacity .3s}
.wseg.on{max-width:130px;opacity:1}
.vp{height:246px;overflow:hidden;perspective:760px;margin-top:6px}
.drum{display:flex;flex-direction:column;transition:transform .45s cubic-bezier(.22,.61,.36,1)}
.ln{height:82px;flex:0 0 82px;transform-origin:50% 50%;transition:transform .45s cubic-bezier(.22,.61,.36,1),opacity .45s;cursor:pointer}
.ln.up{transform:rotateX(46deg) scale(.88);opacity:.42}
.ln.dn{transform:rotateX(-46deg) scale(.88);opacity:.42}
.ln.far{opacity:0;pointer-events:none}
.ln.mid{cursor:default}
.sm{display:flex;align-items:center;gap:5px;height:14px}
.sm b{font-size:11px;font-weight:400;color:var(--text-muted);letter-spacing:.6px}
.ln.mid .sm b{color:var(--text-secondary)}
.sm i{flex:1;height:1px;background:var(--border);font-style:normal}
.sm.bd i{height:2px;background:var(--border-stronger)}
.sm em{font-size:11px;color:var(--text-muted);font-style:normal}
.rw{display:flex;overflow-x:auto;scrollbar-width:none;padding-top:3px;padding-bottom:4px}
.rw::-webkit-scrollbar{display:none}
.rwi{display:flex;gap:3px;margin:0 auto}
.up .rw,.dn .rw{overflow-x:hidden}
.p{flex:0 0 48px;min-width:0;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:2px 1px;border-radius:6px;border:1px solid var(--border);background:var(--surface-2);cursor:pointer;height:56px}
.p>*{flex:0 0 auto}
.p.f{border:none}
.up .p,.dn .p{flex:0 0 38px}
.dd{font-size:15px;font-weight:600;line-height:1.1}
.dm{font-size:11px;line-height:1;max-width:100%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.dm i{font-style:normal}
.mf{display:none}
.p.sel .ms{display:none}
.p.sel .mf{display:inline}
.cdc{font-size:11px;font-weight:600;line-height:1.1;max-width:100%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.up .dm,.dn .dm{display:none}
.p .cty{display:none;font-size:9px;line-height:1.05;max-width:100%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;margin-top:1px}
.p.sel .cty{display:block}
.p.ov{position:relative;box-shadow:-1px 0 0 0 var(--border-strong)}
.p.ov.sel{box-shadow:none}
.rwi{position:relative}
.p.t1 .dd{font-size:13px}
.p.t1 .dm{font-size:10px}
.p.t1 .cdc{font-size:10px;letter-spacing:-.2px}
.p.t2{padding-left:0;padding-right:0}
.p.t2 .dd{font-size:13px}
.p.t2 .dm{font-size:9px}
.p.t2 .cdc{font-size:9px;letter-spacing:-.4px}
.p.sel{outline:2px solid var(--text-primary);outline-offset:1px}
.p.nx{border:2px solid var(--border-accent)}
.mt{font-size:11px;color:var(--text-muted);margin:0 auto;align-self:center}
.crw{height:7px;position:relative}
.crt{position:absolute;top:0;width:0;height:0;border-left:6px solid transparent;border-right:6px solid transparent;border-bottom:7px solid var(--surface-1);transition:left .3s}
.card{background:var(--surface-1);border-radius:12px;padding:12px}
.chd{display:flex;align-items:baseline;justify-content:space-between;gap:6px}
.cdt{font-size:11px;color:var(--text-secondary)}
.ccd{font-size:11px;font-weight:600;padding:1px 7px;border-radius:8px}
.cnm{font-size:15px;font-weight:600;margin-top:6px;line-height:1.25}
.clo{display:flex;align-items:center;gap:6px;margin-top:3px}
.cct{font-size:15px;font-weight:600;line-height:1.25}
.addr{display:flex;align-items:flex-start;gap:8px;margin-top:3px}
.addrt{flex:1;min-width:0;font-size:11px;color:var(--text-secondary);line-height:1.35}
.cpy{flex:0 0 auto;display:inline-flex;align-items:center;justify-content:center;width:22px;height:22px;padding:0;border-radius:6px;border:1px solid var(--border);background:var(--surface-2);color:var(--text-muted);cursor:pointer}
.cpy:hover{color:var(--text-primary)}
.cpy.ok{background:var(--bg-accent);border-color:var(--border-accent);color:var(--text-accent)}
.clo .cpy{margin-left:auto}
.fg{width:19px;height:13px;border-radius:2px;overflow:hidden;flex:0 0 19px;position:relative;border:1px solid var(--border-strong)}
.fg div{position:absolute}
.chips{display:flex;gap:4px;flex-wrap:wrap;margin-top:8px}
.chp{font-size:11px;padding:2px 7px;border-radius:8px;background:var(--surface-2);color:var(--text-secondary);border:1px solid var(--border)}
.dvv{height:1px;background:var(--border);margin:10px 0}
.dl{font-size:11px;font-weight:600}
.fee{font-size:11px;color:var(--text-secondary);margin-top:5px;line-height:1.6}
.pills{display:flex;gap:5px;flex-wrap:wrap;margin-top:9px}
.pl{font-size:11px;font-weight:600;padding:4px 10px;border-radius:14px;border:1px solid var(--border-accent);color:var(--text-accent);background:var(--surface-2);text-decoration:none;display:inline-block}
.pl.q{border-color:var(--border);color:var(--text-secondary)}
.pl.r{background:var(--bg-accent);border-color:var(--border-accent);color:var(--text-accent)}
.facts{margin-top:2px}
.fct{display:flex;align-items:baseline;justify-content:space-between;gap:10px;padding:4px 0}
.fct+.fct{border-top:1px solid var(--border)}
.fk{font-size:11px;color:var(--text-muted)}
.fv{font-size:13px;font-weight:600;color:var(--text-primary);white-space:nowrap}
.wps{display:flex;gap:3px;flex-wrap:wrap;margin-top:10px}
.wp{font-size:9px;line-height:1.5;padding:0 6px;border-radius:7px;background:var(--surface-0);color:var(--text-muted);border:1px solid var(--border)}
.lgd{display:flex;gap:12px;flex-wrap:wrap;font-size:11px;color:var(--text-secondary);justify-content:center;max-width:440px;font-family:var(--sans)}
.sw{display:inline-block;width:9px;height:9px;border-radius:3px;margin-right:4px;vertical-align:-1px}
</style>
<div class="mockwrap">
<div class="ctl" id="mkctl">
<label for="w" id="wl">szerokość</label>
<input type="range" id="w" min="320" max="430" step="1" value="320">
<span class="ro" id="ro">320px · iPhone SE</span>
</div>
<div class="ctl cfg">
<label><input type="checkbox" id="cfgevf" checked> <span>Pokaż przełącznik +EVF w Kalendarzu</span></label>
<span class="cfgn">season scoring config · <code>show_evf_toggle_calendar</code></span>
</div>
<div class="ph" id="ph" style="width:320px">
<div class="nub"></div>
<div class="hd">
<button class="hb" aria-label="Menu">&#9776;</button>
<img class="lgo" src="../assets/SPWS-logo.png" alt="SPWS"><span class="ttl" id="vt">Kalendarz</span>
<div class="lang"><button class="lb" data-l="en">EN</button><button class="lb on" data-l="pl">PL</button></div>
</div>
<div class="fil">
<div class="seg" id="sc"><button class="sg" data-s="ppw">PPW</button><button class="sg on" data-s="all">+EVF</button></div>
</div>
<div class="vp"><div class="drum" id="drum"></div></div>
<div class="crw"><div class="crt" id="crt"></div></div>
<div class="card" id="card"></div>
<div class="envf"><div class="envt" id="envt">
<button class="envb on" type="button" data-e="CERT">CT</button><button class="envb" type="button" data-e="PROD">PD</button>
</div></div>
</div>
<div class="lgd">
<span><span class="sw" style="background:#EAF3DE;border:1px solid #639922"></span>krajowe (PPW/MPW)</span>
<span><span class="sw" style="background:#E6F1FB;border:1px solid #378ADD"></span>puchar EVF (PEW)</span>
<span><span class="sw" style="background:#FAEEDA;border:1px solid #BA7517"></span>międzynarodowe (MŚW/MEW)</span>
<span><span class="sw" style="background:var(--surface-2);border:1px solid var(--border-strong)"></span>zaplanowane</span>
</div>
<p class="mockcap">Real CERT data — all 103 non-skeleton events across four seasons, pulled from <code>vw_calendar</code> on 8 August 2026. Where <code>txt_location</code> holds a venue string rather than a city — a known scraper defect — the city line is omitted and the venue is shown demoted; no city is ever inferred that is not literally present. An asterisk on a seam marks a quarter whose events disagree about which season they belong to. Interface strings are Polish because this surface reaches fencers; this document is English.</p>
<script>
(function(){
var TY={ppw:['#EAF3DE','#3B6D11','#173404'],pew:['#E6F1FB','#185FA5','#042C53'],int:['#FAEEDA','#854F0B','#412402']};
var RG={ppw:'SPWS',pew:'EVF',int:'FIE'};
// EN | PL localisation. Registry codes (SPWS/EVF/FIE), event codes and device
// names are proper nouns and stay untranslated. PL months are genitive because
// they only ever appear in a date ("18 kwietnia"), never standalone.
var lang='pl';
var L={
 pl:{
  mo:['stycznia','lutego','marca','kwietnia','maja','czerwca','lipca','sierpnia','września','października','listopada','grudnia'],
  sm:['sty','lut','mar','kwi','maj','cze','lip','sie','wrz','paź','lis','gru'],
  wn:{E:'Szpada',F:'Floret',S:'Szabla'},
  nm:{PPW:'Puchar Polski Weteranów',MPW:'Mistrzostwa Polski Weteranów','MŚW':'Mistrzostwa Świata Weteranów',MEW:'Mistrzostwa Europy Weteranów',PEW:'European Veterans Circuit'},
  cn:{PL:'Polska',GB:'Wielka Brytania',DE:'Niemcy',GR:'Grecja',BG:'Bułgaria',FR:'Francja',HU:'Węgry',ES:'Hiszpania',BH:'Bahrajn',SE:'Szwecja',IT:'Włochy',BE:'Belgia',AT:'Austria',IE:'Irlandia',CH:'Szwajcaria',GE:'Gruzja'},
  st:{done:'Zakończone',await:'Oczekuje na wyniki',plan:'Zaplanowane',canc:'Odwołane'},
  next:'Najbliższe',empty:'brak zawodów',season:'sezon SPWS-',
  // Polish pluralisation: 1 → singular, 2-4 → nominative plural, 0 and 5+ →
  // genitive plural, EXCEPT 12-14 which take the genitive despite ending 2-4.
  trn:function(n){var a=n%10,b=n%100;
    if(n===1)return 'turniej';
    if(a>=2&&a<=4&&!(b>=12&&b<=14))return 'turnieje';
    return 'turniejów';},
  res:'Wyniki',day:'Dzień',inv:'Komunikat',
  feeL:'Opłata startowa',fee2L:'Opłata (2 bronie)',fee3L:'Opłata (3 bronie)',
  dlL:'Termin rejestracji',regL:'Rejestracja',entL:'Lista zgłoszeń',
  copy:'Kopiuj',copied:'Skopiowano',
  awaitMsg:'Zawody się odbyły — wyniki jeszcze nie wprowadzone',
  cancMsg:'Zawody odwołane przez organizatora',
  title:'Kalendarz',width:'szerokość',nr:' nr '
 },
 en:{
  mo:['January','February','March','April','May','June','July','August','September','October','November','December'],
  sm:['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'],
  wn:{E:'Épée',F:'Foil',S:'Sabre'},
  nm:{PPW:'Polish Veterans Cup',MPW:'Polish Veterans Championships','MŚW':'World Veterans Championships',MEW:'European Veterans Championships',PEW:'European Veterans Circuit'},
  cn:{PL:'Poland',GB:'United Kingdom',DE:'Germany',GR:'Greece',BG:'Bulgaria',FR:'France',HU:'Hungary',ES:'Spain',BH:'Bahrain',SE:'Sweden',IT:'Italy',BE:'Belgium',AT:'Austria',IE:'Ireland',CH:'Switzerland',GE:'Georgia'},
  st:{done:'Completed',await:'Awaiting results',plan:'Scheduled',canc:'Cancelled'},
  next:'Next up',empty:'no events',season:'season SPWS-',
  trn:function(n){return n===1?'tournament':'tournaments';},
  res:'Results',day:'Day',inv:'Invitation',
  feeL:'Entry fee',fee2L:'Fee (2 weapons)',fee3L:'Fee (3 weapons)',
  dlL:'Registration deadline',regL:'Register',entL:'Entry list',
  copy:'Copy',copied:'Copied',
  awaitMsg:'Competition held — results not yet entered',
  cancMsg:'Cancelled by the organiser',
  title:'Calendar',width:'width',nr:' no. '
 }
};
function T(){return L[lang]}
var FL={PL:['h','#fff','#DC143C'],BG:['h','#fff','#00966E','#D62612'],BH:['v','#fff','#CE1126'],HR:['h','#FF0000','#fff','#171796'],FR:['v','#0055A4','#fff','#EF4135'],IT:['v','#009246','#fff','#CE2B37'],DE:['h','#000','#D00','#FFCE00'],SE:['c','#006AA7','#FECC00'],BE:['v','#000','#FAE042','#ED2939'],EE:['h','#0072CE','#000','#fff'],PT:['v','#046A38','#DA291C'],NL:['h','#AE1C28','#fff','#21468B'],GE:['c','#fff','#F00'],ES:['h','#AA151B','#F1BF00','#AA151B'],CH:['c','#DA291C','#fff'],AT:['h','#ED2939','#fff','#ED2939'],HU:['h','#CD2A3E','#fff','#436F4D'],GB:['c','#012169','#fff'],IE:['v','#169B62','#fff','#FF883E'],GR:['h','#0D5EAF','#fff','#0D5EAF'],CA:['v','#D80621','#fff','#D80621']};
function flag(cc){
  var f=FL[cc];if(!f)return '<div class="fg"></div>';
  var k=f[0],c=f.slice(1),h='';
  if(k==='h'){var n=c.length;c.forEach(function(x,i){h+='<div style="left:0;right:0;top:'+(i*100/n)+'%;height:'+(100/n)+'%;background:'+x+'"></div>'})}
  else if(k==='v'){var n2=c.length;c.forEach(function(x,i){h+='<div style="top:0;bottom:0;left:'+(i*100/n2)+'%;width:'+(100/n2)+'%;background:'+x+'"></div>'})}
  else{h='<div style="left:0;right:0;top:0;bottom:0;background:'+c[0]+'"></div><div style="left:0;right:0;top:38%;height:24%;background:'+c[1]+'"></div><div style="top:0;bottom:0;left:32%;width:24%;background:'+c[1]+'"></div>'}
  return '<div class="fg">'+h+'</div>';
}
var TODAY=new Date(2026,7,8);
function v(d,mo,y,c,t,w,s,city,cc,nt,fee,cu,vn,nr){return{d:d,mo:mo,y:y,c:c,t:t,w:w,s:s,city:city,cc:cc,nt:nt,fee:fee,cu:cu,vn:vn,nr:nr}}
var RAW=[
"2022-01-08|PEW2e|||COMPLETED|1|2023-2024","2022-02-25|PEW16e|||COMPLETED|1|2023-2024",
"2023-01-01|IMEW|||COMPLETED|16|2023-2024","2023-01-07|PEW1e|Guilford|Great Britain|COMPLETED|4|2023-2024",
"2023-01-14|GP1|Pabianice|Polska|COMPLETED|20|2023-2024","2023-01-21|PEW17fs|||COMPLETED|2|2023-2024",
"2023-02-12|PEW3s|||COMPLETED|2|2023-2024","2023-02-25|PEW18e|||COMPLETED|2|2023-2024",
"2023-03-04|GP2|Toruń|Polska|COMPLETED|25|2023-2024","2023-03-18|PEW4f|||COMPLETED|3|2023-2024",
"2023-03-23|PEW12f|||COMPLETED|1|2023-2024","2023-04-01|PEW20s|||COMPLETED|3|2023-2024",
"2023-04-14|PEW19e|||COMPLETED|8|2023-2024","2023-06-18|GP3|Niepołomice|Polska|COMPLETED|22|2023-2024",
"2023-07-07|VFC|||COMPLETED|0|2023-2024","2023-09-16|PEW21e|||COMPLETED|5|2023-2024",
"2023-09-16|PEW5fs|||COMPLETED|7|2023-2024","2023-09-23|GP4|Opole|Polska|COMPLETED|22|2023-2024",
"2023-09-24|PEW22e|||COMPLETED|2|2023-2024","2023-10-09|PEW7s|||COMPLETED|1|2023-2024",
"2023-10-28|GP5|Gdańsk|Polska|COMPLETED|20|2023-2024","2023-11-11|PEW6efs|||COMPLETED|9|2023-2024",
"2023-11-18|GP6|Kraków|Polska|COMPLETED|20|2023-2024","2023-12-09|PEW23f|||COMPLETED|1|2023-2024",
"2023-12-16|PEW8fs|||COMPLETED|2|2023-2024","2023-12-16|PEW24e|||COMPLETED|5|2023-2024",
"2024-01-06|PEW25e|||COMPLETED|4|2023-2024","2024-01-06|PEW9e|Guildford|Great Britain|COMPLETED|4|2023-2024",
"2024-01-20|PEW10s|||COMPLETED|1|2023-2024","2024-01-27|GP7|Spała|Polska|COMPLETED|22|2023-2024",
"2024-02-24|PEW11f|||COMPLETED|2|2023-2024","2024-03-02|MPW|Warszawa|Polska|COMPLETED|25|2023-2024",
"2024-04-06|PEW14s|||COMPLETED|1|2023-2024","2024-04-06|PEW13e|||COMPLETED|6|2023-2024",
"2024-04-27|PEW15e|||COMPLETED|3|2023-2024","2024-06-22|GP8|Niepołomice|Polska|COMPLETED|18|2023-2024",
"2024-09-21|PEW1efs|Budapest||COMPLETED|14|2024-2025","2024-09-28|PPW1|Konin|Polska|COMPLETED|23|2024-2025",
"2024-10-26|PPW2|Bytom|Polska|COMPLETED|24|2024-2025","2024-11-16|PEW2efs|Madrid||COMPLETED|11|2024-2025",
"2024-11-30|PPW3|Kraków|Polska|COMPLETED|26|2024-2025","2024-12-07|PEW3fs|Munich|Germany|COMPLETED|5|2024-2025",
"2025-01-04|PEW11e|Guildford|Great Britain|COMPLETED|4|2024-2025","2025-01-05|PEW4f|||COMPLETED|1|2024-2025",
"2025-01-18|PEW5s|||COMPLETED|1|2024-2025","2025-02-01|PEW12e|||COMPLETED|4|2024-2025",
"2025-02-02|PEW6fs|||COMPLETED|3|2024-2025","2025-02-22|PPW4|Warszawa|Polska|COMPLETED|27|2024-2025",
"2025-03-15|PEW13e|||COMPLETED|3|2024-2025","2025-03-29|PEW7s|||COMPLETED|7|2024-2025",
"2025-03-29|PEW8f|Chania|Greece|PLANNED|1|2025-2026","2025-03-29|PEW14e|||COMPLETED|8|2024-2025",
"2025-03-30|PEW8f|||COMPLETED|7|2024-2025","2025-04-26|PPW5|Szczecin|Polska|COMPLETED|23|2024-2025",
"2025-05-03|PEW9|||COMPLETED|0|2024-2025","2025-05-15|PEW15f|||COMPLETED|2|2024-2025",
"2025-05-28|IMEW|Plovdiv|Bulgaria|COMPLETED|17|2024-2025","2025-06-07|MPW|Pabianice|Polska|COMPLETED|25|2024-2025",
"2025-07-05|PEW10efs|Paris|France|COMPLETED|7|2024-2025","2025-09-20|PEW1efs|Budapest|Hungary|COMPLETED|14|2025-2026",
"2025-09-27|PPW1|Opole|Polska|COMPLETED|23|2025-2026","2025-10-25|PPW2|Poznań|Polska|COMPLETED|24|2025-2026",
"2025-11-01|PEW2efs|Madrid|Spain|COMPLETED|13|2025-2026","2025-11-12|IMSW|Manama|Bahrain|IN_PROGRESS|10|2025-2026",
"2025-12-06|PEW3s|Munich|Germany|COMPLETED|3|2025-2026","2025-12-06|PEW21fs|Munich|Germany|COMPLETED|8|2025-2026",
"2025-12-13|PPW3|Warszawa-Łomianki|Polska|COMPLETED|23|2025-2026","2026-01-10|PEW63e|||COMPLETED|1|2025-2026",
"2026-01-10|PEW62efs|||COMPLETED|9|2025-2026","2026-01-11|PEW64s|||COMPLETED|2|2025-2026",
"2026-02-07|PEW5s|Stockholm|Sweden|COMPLETED|1|2025-2026","2026-02-07|PEW31fs|Faches|France|COMPLETED|5|2025-2026",
"2026-02-21|PPW4|Gdańsk|Polska|COMPLETED|24|2025-2026","2026-03-07|PEW4efs|Napoli|Italy|COMPLETED|10|2025-2026",
"2026-03-14|PEW65ef|||COMPLETED|5|2025-2026","2026-03-28|PEW6efs|Jabłonna|Polska|COMPLETED|23|2025-2026",
"2026-03-29|PEW66f|||COMPLETED|3|2025-2026","2026-04-11|PPW5|Gdańsk|Polska|COMPLETED|23|2025-2026",
"2026-04-11|PEW61s|Liège|Belgium|COMPLETED|2|2025-2026","2026-04-18|PEW7ef|Salzburg|Austria|COMPLETED|4|2025-2026",
"2026-05-02|PEW67f|||COMPLETED|4|2025-2026","2026-05-14|DMEW|Complexe Sportif Omnisports des Vauzelles|France|PLANNED|6|2025-2026",
"2026-05-30|PEW9efs|Dublin|Ireland|IN_PROGRESS|10|2025-2026","2026-06-20|MPW|Warszawa|Polska|COMPLETED|28|2025-2026",
"2026-09-12|PEW0efs|||CANCELLED|12|2026-2027","2026-09-19|PEW1f|Savoy Terrace - Buda Castle|Hungary|PLANNED|2|2026-2027",
"2026-09-26|PPW1|Opole|Polska|PLANNED|0|2026-2027","2026-10-09|MSW|TBILISI|GRUZJA|PLANNED|0|2026-2027",
"2026-10-31|PEW2es|POLIDEPORTIVO MUNICIPAL DE MORATALAZ|Spain|PLANNED|8|2026-2027",
"2026-11-14|PEW3ef|||PLANNED|8|2026-2027",
"2026-11-28|PEW4fs|Sporthalle der Städtischen Berufsschule für Informationstechnik|Germany|PLANNED|8|2026-2027",
"2026-12-12|PEW5efs|||PLANNED|12|2026-2027","2027-01-09|PEW6efs|Guildford Spectrum|United Kingdom|PLANNED|12|2026-2027",
"2027-01-30|PEW7efs|||PLANNED|6|2026-2027","2027-02-06|PEW9e|Vaudoise aréna - Lausanne|Switzerland|PLANNED|4|2026-2027",
"2027-02-06|PEW8fs|Salle Jean Zay|France|PLANNED|8|2026-2027","2027-03-06|PEW10efs|Palavesuvio|Italy|PLANNED|12|2026-2027",
"2027-03-13|PEW11ef|Stora mossen IP idrottshall|Sweden|PLANNED|8|2026-2027","2027-04-10|PEW12s|Liège|Belgium|PLANNED|4|2026-2027",
"2027-04-24|PEW13ef|Sporthalle HAK 2 - Salzburg|Austria|PLANNED|8|2026-2027","2027-05-22|PEW14es|||PLANNED|8|2026-2027",
"2027-05-29|PEW15efs|UCD Sport Center Dublin|Ireland|PLANNED|12|2026-2027","2027-06-18|PEW16efs|||PLANNED|6|2026-2027"];
var ISO={'Polska':'PL','Great Britain':'GB','United Kingdom':'GB','Germany':'DE','Greece':'GR','Bulgaria':'BG','France':'FR','Hungary':'HU','Spain':'ES','Bahrain':'BH','Sweden':'SE','Italy':'IT','Belgium':'BE','Austria':'AT','Ireland':'IE','Switzerland':'CH','GRUZJA':'GE'};
function typeOf(c){
  if(/^(PPW|MPW|GP)/.test(c))return 'ppw';
  if(/^PEW/.test(c))return 'pew';
  return 'int';
}
var VENUE_RE=/sporthalle|salle |complexe|polideportivo|palavesuvio|spectrum|idrottshall|topsporthal|sport ?cent|sports city|castle|pavilh|palais|paladozza|country hall|variety village|olympic palace|arena|ar[eé]na|berufsschule/i;
// txt_location is specified to hold a CITY. On PEW rows the scraper wrote the
// venue into it instead. Split what is recoverable, leave the rest unknown —
// never guess a city that is not in the string.
function splitLoc(v){
  if(!v) return {city:'',venue:''};
  var m=v.split(/\s+-\s+/);
  if(m.length===2 && /^[A-ZŁŚŻŹĆÓĄĘŃ][^\s]*$/.test(m[1].trim())) return {city:m[1].trim(),venue:m[0].trim()};
  if(VENUE_RE.test(v)) return {city:'',venue:v};
  return {city:v,venue:''};
}
function panelLabel(e){
  if(e.t==='pew'){var m=e.c.match(/^PEW-?(\d*)/);return 'EVF'+((m&&m[1])?m[1]:'')}
  return e.c.replace(/[efs]+$/,'');
}
function weaponsOf(c){var m=c.match(/[efs]+$/);return m?m[0].toUpperCase():'EFS'}
var EV=RAW.map(function(r){
  var p=r.split('|'),d=p[0].split('-').map(Number);
  var cc=ISO[p[3]]||'';
  return {y:d[0],mo:d[1]-1,d:d[2],iso:p[0],c:p[1],loc:p[2],cc:cc,ccRaw:p[3],
          st:p[4],nt:+p[5],season:p[6],t:typeOf(p[1]),w:weaponsOf(p[1])};
});
var TODAY_ISO='2026-08-08';
function stOf(e){
  if(e.st==='CANCELLED')return 'canc';
  if(e.st==='COMPLETED'||e.st==='IN_PROGRESS')return 'done';
  return e.iso < TODAY_ISO ? 'await' : 'plan';
}
// Fee, deadline and registration are ILLUSTRATIVE in this mock. CERT carries a
// fee on 28/103 events and a deadline on 5/103, and this fixture never had
// those columns at all — so they are derived deterministically from the event
// code purely to show the card's shape across present/absent combinations.
// Everything else in this mock is real CERT data.
function fmtDL(dt){return pad(dt.getUTCDate())+'/'+pad(dt.getUTCMonth()+1)+'/'+dt.getUTCFullYear()}
EV.forEach(function(e){
  var L=splitLoc(e.loc);e.city=L.city;e.venue=L.venue;e.s=stOf(e);
  if(/^(PEW1efs|PEW2efs|PEW6efs|IMEW|IMSW)$/.test(e.c))e.urls=e.nt>10?3:2;
  var hsh=0;for(var q=0;q<e.c.length;q++)hsh=(hsh*31+e.c.charCodeAt(q))>>>0;
  e.cur=e.t==='ppw'?'PLN':(e.cc==='GB'?'GBP':'EUR');
  // A tiered fee can only exist where the tier does: an event covering foil
  // alone has no two- or three-weapon price to quote. So the tiers are gated
  // on the event's own weapon count, not sprinkled at random.
  if(hsh%10<5){
    e.fee=e.cur==='PLN'?(60+(hsh%5)*10):(35+(hsh%6)*5);
    if(e.w.length>=2)e.fee2=Math.round(e.fee*1.7);
    if(e.w.length>=3)e.fee3=Math.round(e.fee*2.3);
  }
  e.inv=hsh%7!==0;
  // Registration only exists while the event is still ahead of you. Mirrors the
  // real rule (today <= dt_registration_deadline ?? dt_start), under which an
  // event that has already been held can never show a live registration link.
  if(e.s==='plan'){
    e.reg=hsh%4!==0;
    e.ent=hsh%3!==0;
    if(e.reg){var d0=new Date(Date.UTC(e.y,e.mo,e.d));d0.setUTCDate(d0.getUTCDate()-(10+hsh%12));e.dl=d0;}
  }
});
// The card opens on the next upcoming event, so give that one the full set —
// fee, deadline and both links — to make the richest state the default view.
(function(){var f=null;EV.forEach(function(e){if(!f&&e.s==='plan')f=e});
 if(!f)return; f.reg=true; f.inv=true; f.ent=true;
 if(f.fee==null)f.fee=f.cur==='PLN'?90:45;
 if(f.w.length>=2&&f.fee2==null)f.fee2=Math.round(f.fee*1.7);
 if(f.w.length>=3&&f.fee3==null)f.fee3=Math.round(f.fee*2.3);
 if(!f.dl){var d1=new Date(Date.UTC(f.y,f.mo,f.d));d1.setUTCDate(d1.getUTCDate()-14);f.dl=d1;}})();
EV.sort(function(a,b){return a.iso<b.iso?-1:a.iso>b.iso?1:0});
var QM={},QO=[];
EV.forEach(function(e){
  var qi=Math.floor(e.mo/3), k=e.y+'.'+qi;
  if(!QM[k]){QM[k]={q:(qi+1)+'Q'+String(e.y).slice(2),k:k,y:e.y,qi:qi,v:[],ss:{}};QO.push(QM[k])}
  QM[k].v.push(e); QM[k].ss[e.season]=(QM[k].ss[e.season]||0)+1;
});
QO.sort(function(a,b){return a.y-b.y||a.qi-b.qi});
QO.forEach(function(g){
  var best=null,n=0;
  for(var k in g.ss){if(g.ss[k]>n){n=g.ss[k];best=k}}
  g.s=best; g.mixed=Object.keys(g.ss).length>1;
});
var Q=QO;
function esc(s){return String(s).replace(/&/g,'&amp;').replace(/"/g,'&quot;').replace(/</g,'&lt;').replace(/>/g,'&gt;')}
// What lands on the clipboard is the FULL address — venue, city, country —
// even though the card shows the country only as a flag. You paste this into
// a maps app or send it to a driver; a bare venue fragment is not enough.
function addrOf(e){var p=[];if(e.venue)p.push(e.venue);if(e.city)p.push(e.city);if(e.cc)p.push(T().cn[e.cc]||e.ccRaw);return p.join(', ')}
// Inline SVG, no external requests — the embed runs under a strict CSP and an
// icon font or sprite sheet would be a second thing that can fail to load.
var ICO_COPY='<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"><rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>';
var ICO_OK='<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"><path d="M20 6L9 17l-5-5"/></svg>';
// The button shows no text, so aria-label and title ARE the label — they still
// have to be translated. Dropping the word from the surface does not drop it
// from the locale files; an icon-only control with no accessible name is
// simply an unlabelled button to a screen reader.
function cpyBtn(e){var a=addrOf(e);return a?'<button class="cpy" type="button" aria-label="'+esc(T().copy)+'" title="'+esc(T().copy)+'" data-copy="'+esc(a)+'">'+ICO_COPY+'</button>':''}
function nameOf(c){var N=T().nm;if(c.indexOf('PPW')===0)return N.PPW+T().nr+(c.slice(3)||'0');if(c.indexOf('PEW')===0)return N.PEW;return N[c]||c}
var drum=document.getElementById('drum'),card=document.getElementById('card'),crt=document.getElementById('crt'),vp=document.querySelector('.vp');
var sc=document.getElementById('sc');
var SCOPE_ONLY=1;
var W={E:1,F:1,S:1};var active=(function(){for(var i=0;i<Q.length;i++){for(var j=0;j<Q[i].v.length;j++){if(Q[i].v[j].s==='plan')return i}}return Q.length-1})(),H=82,W={E:1,F:1,S:1},SC='all',sel=null;
function ok(e){return SC==='ppw'?e.t==='ppw':true}
function visOf(i){return Q[i].v.filter(ok)}
function build(){
  var seen=0;drum.innerHTML='';
  Q.forEach(function(g,i){
    var ln=document.createElement('div');ln.className='ln';ln.dataset.i=i;
    var bd=i>0&&Q[i-1].s!==g.s;
    var sm=document.createElement('div');sm.className='sm'+(bd?' bd':'');
    sm.innerHTML='<b>'+g.q+'</b><i></i><em></em>';
    var rw=document.createElement('div');rw.className='rw';
    var inr=document.createElement('div');inr.className='rwi';
    var vis=g.v.filter(ok);
    if(!vis.length){var m=document.createElement('span');m.className='mt';m.textContent=T().empty;rw.appendChild(m)}
    vis.forEach(function(e,j){
      var c=TY[e.t],isn=e.s==='plan'&&!seen;if(isn)seen=1;e._n=isn;
      var p=document.createElement('div');p.className='p'+((e.s==='done'||e.s==='await')?' f':isn?' nx':'');
      p.dataset.q=i;p.dataset.j=j;p.dataset.prio=(e.t==='pew'?'0':'1');p.dataset.city=(e.city||e.venue)?'1':'0';
      if(e.s==='done'||e.s==='await')p.style.background=c[0];
      if(e.s==='canc')p.style.opacity=.45;
      if(e.s==='plan'&&!isn)p.style.borderLeft='2px solid '+c[1];
      var dc=(e.s==='done'||e.s==='await')?c[1]:isn?'var(--text-accent)':'var(--text-secondary)';
      var tc=(e.s==='done'||e.s==='await')?c[2]:'var(--text-primary)';
      p.innerHTML='<span class="dd" style="color:'+dc+'">'+e.d+'</span><span class="dm" style="color:'+dc+'"><i class="ms">'+T().sm[e.mo]+'</i><i class="mf">'+T().mo[e.mo]+'</i></span><span class="cdc" style="color:'+tc+'">'+panelLabel(e)+'</span>'+((e.city||e.venue)?'<span class="cty" style="color:'+(e.s==='done'?c[1]:'var(--text-muted)')+'">'+(e.city||e.venue)+'</span>':'');
      inr.appendChild(p);
    });
    if(vis.length)rw.appendChild(inr);
    ln.appendChild(sm);ln.appendChild(rw);drum.appendChild(ln);
  });
}
function pad(n){return n<10?'0'+n:''+n}
function showCard(e){
  var c=TY[e.t],nw=e.w.length;
  var ST=T().st;
  var LB={done:[ST.done,c[0],c[2]],await:[ST.await,'#FAEEDA','#412402'],
          plan:[ST.plan,'var(--surface-2)','var(--text-secondary)'],canc:[ST.canc,'#FCEBEB','#501313']};
  var stt=e._n?[T().next,'var(--bg-accent)','var(--text-accent)']:LB[e.s];
  var miss='';
  var h='<div class="chd"><span class="cdt">'+e.d+' '+T().mo[e.mo]+' '+e.y+'</span>'+
    '<span class="ccd" style="background:'+c[0]+';color:'+c[2]+'">'+e.c+'</span></div>'+
    '<div class="cnm">'+nameOf(e.c)+'</div>'+
    (e.city?'<div class="clo">'+(e.cc?flag(e.cc):'')+'<span class="cct">'+e.city+'</span>'+(e.venue?'':cpyBtn(e))+'</div>':'')+
    (e.venue?'<div class="addr"><span class="addrt">'+e.venue+'</span>'+cpyBtn(e)+'</div>':'')+
    '<div class="chips"><span class="chp" style="background:'+stt[1]+';color:'+stt[2]+';border-color:transparent">'+stt[0]+'</span>'+
    '<span class="chp">'+RG[e.t]+'</span></div>'+
    '<div class="dvv"></div>';
  // The four fields that actually drive a decision: fee, deadline, and the two
  // URLs. Each row is omitted entirely when its field is empty — no placeholders.
  var facts='';
  // Each tier is independent — render one line per non-null field, never a
  // block gated on the base fee being present.
  if(e.fee!=null)facts+='<div class="fct"><span class="fk">'+T().feeL+'</span><span class="fv">'+e.fee+' '+e.cur+'</span></div>';
  if(e.fee2!=null)facts+='<div class="fct"><span class="fk">'+T().fee2L+'</span><span class="fv">'+e.fee2+' '+e.cur+'</span></div>';
  if(e.fee3!=null)facts+='<div class="fct"><span class="fk">'+T().fee3L+'</span><span class="fv">'+e.fee3+' '+e.cur+'</span></div>';
  if(e.dl)facts+='<div class="fct"><span class="fk">'+T().dlL+'</span><span class="fv">'+fmtDL(e.dl)+'</span></div>';
  if(facts)h+='<div class="facts">'+facts+'</div>';
  if(e.s==='await')h+='<div class="dl" style="color:#854F0B">'+T().awaitMsg+'</div>';
  else if(e.s==='canc')h+='<div class="dl" style="color:#A32D2D">'+T().cancMsg+'</div>';
  var pills=[];
  if(e.s==='done'){
    var slots=e.urls||1;
    var lbl=slots===1?[T().res]:(function(){var a=[];for(var i2=1;i2<=slots;i2++)a.push(T().day+' '+i2);return a})();
    lbl.forEach(function(x){pills.push('<a class="pl" href="#">'+x+' &rarr;</a>')});
  }
  if(e.reg)pills.push('<a class="pl r" href="#">'+T().regL+' &rarr;</a>');
  // Entry list shows only while the start date is still ahead — 'plan' is
  // exactly that (future date, not cancelled). Deliberately NOT tied to the
  // registration deadline: who has entered stays worth reading after entries
  // close, right up until the event begins.
  if(e.ent)pills.push('<a class="pl" href="#">'+T().entL+' &rarr;</a>');
  if(e.inv)pills.push('<a class="pl q" href="#">'+T().inv+' &rarr;</a>');
  if(pills.length)h+='<div class="pills">'+pills.join('')+'</div>';
  h+='<div class="wps">'+e.w.split('').map(function(x){return '<span class="wp">'+T().wn[x]+'</span>'}).join('')+'</div>';
  card.innerHTML=h;
}
function fitRow(){
  var all=[].slice.call(drum.querySelectorAll('.p'));
  all.forEach(function(p){p.style.flex='';p.style.marginLeft='';p.style.zIndex='';p.classList.remove('ov')});
  [].slice.call(drum.querySelectorAll('.rwi')).forEach(function(r){r.style.gap=''});
  var mid=drum.querySelector('.ln.mid'); if(!mid)return;
  var rw=mid.querySelector('.rw'), inr=mid.querySelector('.rwi'); if(!inr)return;
  var ps=[].slice.call(inr.querySelectorAll('.p')); if(!ps.length)return;
  var W=48, GAP=3, n=ps.length, avail=rw.clientWidth;
  var selP=inr.querySelector('.p.sel');
  // The selected panel spells the month out in full, so it can never be the
  // plain 48px: "października" alone measures 66px. 74px leaves real headroom
  // for the longest month in either language; a city still needs the full 78px.
  var WSEL=(selP&&selP.dataset.city==='1')?78:74;
  if((n-1)*(W+GAP)+WSEL<=avail){
    ps.forEach(function(p){p.style.flex='0 0 '+(p===selP?WSEL:W)+'px'});
    return;
  }
  var S=Math.floor((avail-WSEL)/(n-1));
  S=Math.max(13,Math.min(W+GAP,S));
  inr.style.gap='0px';
  var sj=sel?sel.j:0;
  ps.forEach(function(p,i2){
    p.style.flex='0 0 '+(p===selP?WSEL:W)+'px';
    if(i2>0)p.style.marginLeft=(-(W-S))+'px';
    p.style.zIndex=String(200-Math.abs(i2-sj)*2);
    p.classList.add('ov');
  });
}
function caret(){
  var p=drum.querySelector('.p.sel');if(!p){crt.style.opacity=0;return}
  crt.style.opacity=1;
  var r=p.getBoundingClientRect(),vr=vp.getBoundingClientRect();
  crt.style.left=Math.max(8,Math.min(vr.width-20,r.left+r.width/2-vr.left-6))+'px';
}
function select(qi,j){
  var vis=visOf(qi);if(!vis.length)return;
  j=Math.max(0,Math.min(vis.length-1,j));sel={q:qi,j:j};
  [].slice.call(drum.querySelectorAll('.p')).forEach(function(p){
    p.classList.toggle('sel',+p.dataset.q===qi&&+p.dataset.j===j)});
  showCard(vis[j]);fitRow();caret();
}
function render(){
  var rows=[].slice.call(drum.querySelectorAll('.ln'));
  drum.style.transform='translateY('+(-(active-1)*H)+'px)';
  rows.forEach(function(ln,i){
    var d=i-active,bd=ln.querySelector('.sm').classList.contains('bd');
    ln.className='ln'+(d===-1?' up':d===1?' dn':d===0?' mid':' far');
    ln.querySelector('em').textContent=(d===0||bd)?Q[i].s.slice(2,4)+'/'+Q[i].s.slice(7,9)+(Q[i].mixed?' *':''):'';
  });
  fitRow();setTimeout(function(){fitRow();caret()},460);
}
card.addEventListener('click',function(ev){
  var b=ev.target.closest('.cpy'); if(!b)return;
  ev.preventDefault();
  var txt=b.dataset.copy||'';
  function done(){
    b.innerHTML=ICO_OK;b.classList.add('ok');
    b.setAttribute('aria-label',T().copied);b.setAttribute('title',T().copied);
    setTimeout(function(){b.innerHTML=ICO_COPY;b.classList.remove('ok');
      b.setAttribute('aria-label',T().copy);b.setAttribute('title',T().copy);},1400);}
  // execCommand fallback matters here: navigator.clipboard needs a secure
  // context, and the public embed may sit on a plain-http host page.
  function fallback(){var ta=document.createElement('textarea');ta.value=txt;
    ta.setAttribute('readonly','');ta.style.position='fixed';ta.style.top='-1000px';
    document.body.appendChild(ta);ta.select();
    try{document.execCommand('copy')}catch(_){}
    document.body.removeChild(ta);done();}
  if(navigator.clipboard&&navigator.clipboard.writeText){
    navigator.clipboard.writeText(txt).then(done,fallback);
  }else fallback();
});
drum.addEventListener('click',function(ev){
  var p=ev.target.closest('.p');
  if(p&&+p.dataset.q===active){select(active,+p.dataset.j);return}
  var ln=ev.target.closest('.ln');if(!ln)return;
  var i=+ln.dataset.i;if(i!==active&&visOf(i).length){active=i;render();select(i,0)}
});
sc.addEventListener('click',function(ev){
  var b=ev.target.closest('.sg');if(!b)return;SC=b.dataset.s;
  [].slice.call(sc.querySelectorAll('.sg')).forEach(function(x){x.className='sg'+(x.dataset.s===SC?' on':'')});
  build();render();
  var qi=active;while(qi<Q.length&&!visOf(qi).length)qi++;
  if(qi>=Q.length){qi=active;while(qi>=0&&!visOf(qi).length)qi--}
  if(qi>=0&&qi<Q.length){active=qi;render();select(qi,0)}
});
// Season scoring config: show_evf_toggle_calendar ("Pokaż przełącznik +EVF w
// Kalendarzu"). Turning it OFF does not merely hide the control — it forces the
// domestic scope, exactly as `!showEvfToggle || scopeFilter === 'ppw'` does in
// CalendarView today. Hiding the button without constraining the data would
// leave EVF events on screen with no way to filter them out.
document.getElementById('cfgevf').addEventListener('change',function(){
  var on=this.checked;
  document.querySelector('.fil').style.display=on?'':'none';
  SC=on?'all':'ppw';
  [].slice.call(sc.querySelectorAll('.sg')).forEach(function(x){x.className='sg'+(x.dataset.s===SC?' on':'')});
  build();render();
  var qi=active;while(qi<Q.length&&!visOf(qi).length)qi++;
  if(qi>=Q.length){qi=active;while(qi>=0&&!visOf(qi).length)qi--}
  if(qi>=0&&qi<Q.length){active=qi;render();select(qi,0)}
});
[].slice.call(document.querySelectorAll('.lb')).forEach(function(b){
  b.addEventListener('click',function(){
    if(lang===b.dataset.l)return;
    lang=b.dataset.l;
    [].slice.call(document.querySelectorAll('.lb')).forEach(function(x){x.className='lb'+(x===b?' on':'')});
    document.getElementById('vt').textContent=T().title;
    document.getElementById('wl').textContent=T().width;
    // build() recreates the panels, which drops the .sel class — keep the
    // current selection and restore it so switching language does not move you.
    var keep=sel?{q:sel.q,j:sel.j}:null;
    build();render();
    if(keep)select(keep.q,keep.j);else select(active,0);
  })});
// CERT/PROD switch. Temporary by design — it exists only because both
// environments are served from GitHub Pages today, and retires when PROD moves
// to the WordPress CMS. Labels are environment codes, so they never translate.
document.getElementById('envt').addEventListener('click',function(ev){
  var b=ev.target.closest('.envb'); if(!b)return;
  [].slice.call(this.querySelectorAll('.envb')).forEach(function(x){x.className='envb'+(x===b?' on':'')});
});
var w=document.getElementById('w'),ro=document.getElementById('ro'),ph=document.getElementById('ph');
function dev(n){return n<=320?'iPhone SE':n<=360?'Pixel / Galaxy':n<=375?'iPhone SE2 / 13 mini':n<=393?'iPhone 15 / Pixel 8':n<=414?'iPhone Plus':'iPhone Pro Max'}
w.addEventListener('input',function(){ph.style.width=w.value+'px';ro.textContent=w.value+'px · '+dev(+w.value);setTimeout(function(){fitRow();caret()},220)});
build();render();(function(){var v=visOf(active);for(var j=0;j<v.length;j++){if(v[j].s==='plan'){select(active,j);return}}select(active,0)})();
})();
</script>
</div>

## Context

The public Calendar is the SPWS surface a fencer opens to decide whether to enter a competition. It renders today as three stacked mechanisms in `CalendarView.svelte` (659 lines): a month-grouped reverse-chronological event list, a flat rolling-progress strip above it, and a season dropdown that clamps the whole view to one season.

**The complaint that started this was specific, and it is a design defect rather than a taste preference.** The progress strip encodes two independent variables in one visual channel: hue carries event type (`pew` / `imew` / `mpw` / `ppw` via `slotTypeClass()`, `CalendarView.svelte:241-246`), and *lightness of that same hue* carries completion. Two variables sharing one channel means neither reads cleanly — a light PEW slot and a dark PPW slot are not comparable on either dimension. The strip is also gated to the active season (`isActiveSeason`, read only at `:34` and `:269`), so it vanishes exactly when a fencer is looking at history.

A second, independent finding came from the card content. Pulled live from `vw_calendar` on 2026-08-08 — 126 rows, 103 after excluding `CREATED` skeletons:

| Field | Populated | On the card today |
| --- | --- | --- |
| `num_tournaments` | 103/103 | **Yes**, prominently |
| `num_entry_fee` | 28/103 | Yes |
| `txt_venue_address` | 22/103 | **No** |
| `dt_registration_deadline` | 5/103 | Yes |
| Fee tiers (`_2w` / `_3w`) | 1/103 | Yes |

The tournament count was the easiest thing to display and the least useful thing to read: it answers a question nobody asks. Meanwhile the venue address — the field a fencer pastes into a maps app or sends to a driver — was absent entirely. The list optimised for what the data had, not for what the decision needs.

The same pull established four data realities this design must survive rather than assume away:

- **Location is missing on PEW only.** Domestic 22/22 = 100%; PEW 30/75 = 40%, improving by season as the scraper gained the field. A location-dependent layout would degrade only for international events.
- **`txt_country` is free text in mixed languages** — `Polska`, `Germany`, `GRUZJA`, and both `Great Britain` and `United Kingdom` for one country.
- **The scraper writes venue strings into the city field.** `Sporthalle der Städtischen Berufsschule für Informationstechnik` and `Savoy Terrace - Buda Castle` are stored as `txt_location`.
- **`arr_weapons` is unusable.** The column exists with `DEFAULT '{EPEE,FOIL,SABRE}'` and 102 of 103 events sit on that default, so "all three" means both *genuinely all three* and *nobody set this*. The real weapon lives in the lowercase code suffix per ADR-046.

Finally, **320px is the floor** — an iPhone SE is a real device in this user base, and the embed sits inside a host page with no width guarantee.

## Decision

Replace the month-grouped list, the rolling-progress strip and the season dropdown with a **rotating three-row quarter barrel** that is the primary navigation control, driving a **single full-detail event card** beneath it.

A live, interactive mock built on all 103 real CERT events is the **acceptance criterion** for this ADR: the work is done when the implemented component matches it. It sits at the top of `doc/plans/kalendarz-barrel-2026-08-08.html`. Reading that file as source does not exercise it; it must be served and driven.

### 1 · Each variable gets its own channel

The defect above is fixed by separation, not by re-tuning colours:

| Variable | Channel |
| --- | --- |
| Event type | **Hue** |
| Completed | **Fill** (not lightness of the type hue) |
| Next upcoming | **Ring** |

### 2 · Three-row drum, rotation by `translateY`, facing by `rotateX`

The focused quarter is centred; the previous quarter recedes above at `rotateX(46deg)` and the next below at `-46deg`. Rotation is a `translateY` on the drum; per-row facing angle is `rotateX`. **The DOM never re-renders on rotate — only classes change.**

### 3 · Detail tiers follow rotation

The focused row shows day, month and code. Receded rows drop to day + code at 38px. The selected panel additionally carries the city, spells its month out in full (`19 września`, not `19 wrz`), and is 56px tall.

### 4 · Continuous history; the barrel owns season state

The drum rolls back to the start of history with **no season clamp**. Crossing a season boundary *drives* season state rather than being constrained by it — which is what allowed the season dropdown to be deleted. Quarters may legitimately hold two seasons: CERT contains `PEW2e-2023-2024` dated `2022-01-08` and `PEW8f-2025-2026` sitting among 2024-25 events.

### 5 · Overlap, not shrink

When a quarter's panels do not fit the viewport, they **fan and overlap at full size** rather than compressing. Compression is the conventional response and it is wrong here: at 320px a compressed panel stops being readable, whereas an overlapped one still exposes an edge.

- Positions are fixed at `i × S`, where `S = (available − W_selected) ÷ (n − 1)`, floor 13px.
- `z-index = 200 − |i − selected| × 2`, so the stack peaks on the selection. Panels left of it expose their left edge; panels right of it expose their right edge.
- **Only `z-index` changes on select** — selecting is a paint operation, never a layout reflow.
- The selected panel widens to 78px to carry a city, 74px without one. Uniform negative margins mean every later panel shifts right automatically, with no special-casing.

Verified in the mock at the 320px floor: five panels sit flat, six fan; a ten-panel quarter fans at `margin-left: -23px` (S = 25px) with z-indices 192/194/196/198/**200**/198/196/194/192/190.

### 6 · Whole row is the tap target

Tapping a receded row rotates it to centre. Tapping a panel on the focused row selects that event. There is no separate affordance to discover.

### 7 · Engraved seams

The quarter label (`4Q26`) sits at 11px muted on a hairline above each row and rotates with it. The season code (`25/26`) sits at the seam's right end on the focused row, and **permanently** on season-boundary seams, which take a 2px stronger rule. This is where the deleted dropdown's information went.

### 8 · One card, ordered by what a fencer acts on

Identity first (date, code, name, place), then a two-chip status line, then a rule, then **the decision block**: entry fee, both tiered fees, registration deadline, and the two links. Weapons close the card as small muted pills — they qualify an event, they are not why anyone opened it.

- **Optional fields render only when present.** No `brak danych` placeholders.
- **Fee tiers are gated on the event's weapon count.** An event covering foil alone has no two-weapon price; a populated `num_entry_fee_2w` there is a *data error*, not something to render. The tiers are otherwise **independent, not a set** — an event may fill the base fee and `_3w` while leaving `_2w` null, so one line per non-null field.
- **Currency is stored, not assumed:** `txt_entry_fee_currency ?? 'PLN'`.
- **Location is always a city, never a venue.** Venue belongs in `txt_venue_address`. The card never infers a city that is not literally in the string. **If `txt_location` holds anything, it appears** — classification picks which line it goes on, never whether it is visible. This fixes a live defect where 9 events with a location displayed none.
- **The venue address replaces the old country-and-season row** and carries a 22px copy-icon button. What lands on the clipboard is the **full composed address** — venue, city, country name — even though the card shows only a flag, because a string pasted into a maps app cannot see the flag. The button attaches to the city line when there is no venue, and is absent only when there is no location at all.
- **The copy button has no visible text**, so its `aria-label` and `title` *are* its accessible name and both are translated and both flip to `Skopiowano` / `Copied` on success. The glyph is **inline SVG** — ADR-007's strict CSP makes an icon font or sprite one more asset that can fail to load. Use `navigator.clipboard.writeText()` with an `execCommand` fallback, since the Clipboard API needs a secure context and the public embed may sit on a plain-http host page.

### 9 · Entry list is gated on `dt_start > today`, not on the registration cutoff

**This is a deliberate behaviour change** and it amends ADR-079 §7. Today both links share one cutoff, `regCutoff = dt_registration_deadline ?? dt_start` (`CalendarView.svelte:53-58`), so on an event with a stored deadline the entry list disappears the moment entries close.

That is the wrong rule for this link. Who has entered becomes **more** interesting once the list is final: you check the draw, see who is in your category, and decide whether the trip is worth it. Registration and the entry list answer different questions and must not share a date. The entry list is additionally suppressed on a `CANCELLED` event.

The registration side is **unchanged** and ported verbatim from ADR-030: the deadline *text* has its own stricter test requiring `dt_registration_deadline` non-null, while the links survive until the deadline or, absent one, until the event starts — which is what keeps them live for the 98 of 103 events with no stored deadline. `regUrgent` still turns the block red under seven days. ADR-079's in-app modal behaviour is unchanged: `bool_use_spws_registration` calls `preventDefault()` and opens `RegistrationModal`; an external URL still navigates.

**Consequence for implementation:** `registrationState(event, today)` must return the registration and entry-list flags **separately**, not one shared `regOpen`.

No existing test pins the old coupling — every test touching `.entry-list-link` sets a future deadline equal to `dt_start`, and the one past-deadline test asserts only the registration link — so this costs **new** tests rather than rewrites. The uncomfortable half is why it was cheap: the coupling was never covered, so nothing would have caught it drifting either way.

### 10 · One scope control, `PPW | +EVF`, governed per season

Centred below the header. It is governed by the scoring-config field `show_evf_toggle_calendar` ("Pokaż przełącznik +EVF w Kalendarzu"), which resolves with a default of **`true`** — the opposite of its ranklist sibling `show_evf_toggle`, split deliberately by ADR-044 so the two surfaces are independent. Do not re-merge them.

**Off does not merely hide the button — it constrains the data.** `CalendarView.svelte:291` reads `!showEvfToggle || scopeFilter === 'ppw'`, so with the config off the calendar is domestic-only regardless of scope state; hiding the control alone would strand EVF events on screen with no way to filter them. In the mock this is the difference between 103 panels and 22. This behaviour is real today but was never recorded in ADR-017, which is why that ADR is amended here.

The flag arrives asynchronously from `fn_export_scoring_config`, so the scope default must **re-sync on every change** until the user picks explicitly. A scope initialised once at mount is wrong for the first paint.

`isInternationalEvent` is ported verbatim: `bool_has_international || /^(PEW|MEW|MSW|PSW|IMEW|IMSW)/.test(txt_code)`.

### 11 · Results links are labelled by day, never by weapon

One URL renders as `Wyniki`; several render as `Dzień 1`, `Dzień 2`. Two weapons on one day still read as that day.

This follows ADR-040, which holds the five URL slots to be equal-status with no role labels, no per-slot enum and no primary pointer. An earlier per-weapon design was wrong and was removed. **The label is derived at render time from the URL's own content and never stored**, which is what keeps it compatible — Engarde encodes the date in the path (`2025_09_20_pbt`), so those URLs label themselves. A stored role remains rejected.

Where a platform does not encode the date, fall back to **bare numbering** — `Wyniki 1`, `Wyniki 2`. ADR-040 forbids inferring day from slot position, because slots are compacted on save and therefore non-semantic. Bare numbering degrades honestly and fails visibly, which signals which platforms need a parser.

### 12 · Localisation, including three-form Polish plurals

Every string goes through `t()` and `locales/{en,pl}.json`. Registry codes (`SPWS`, `EVF`, `FIE`), event codes and device names are proper nouns and stay untranslated.

Two things a naive port gets wrong, both amending ADR-005:

- **Polish months in a date are genitive** — `18 kwietnia`, not `18 kwiecień`. Because they appear only inside dates here the genitive forms can be stored directly, but a `month_N` key reused for a standalone heading elsewhere would then read wrongly. The calendar gets **its own month keys** rather than borrowing `month_1…12`.
- **Polish has three plural forms and the count picks between them** — `1 turniej` · `2–4 turnieje` · `0 and 5+ turniejów` — with the trap that **12, 13 and 14 take the genitive** despite ending in 2–4, while 22, 23 and 24 do not. ADR-005 recorded "no pluralisation support" as an accepted trade-off on the grounds that no key then contained a plural. **That trade-off has since expired in production:** `tournaments_count` is a flat string concatenated with the count at `CalendarView.svelte:72`, so `2 turniejów` and `1 tournaments` are both on screen today. A count-keyed pluralisation helper replaces it. ADR-063 already established Polish grammatical case as a first-class concern in this codebase, so this is an extension of an existing principle rather than a new one.

### 13 · Derivation moves into a pure module; no SQL in this work

All derivation currently lives inline in the component, which is why its test file is 788 lines of component-mounting tests. `lib/calendarQuarters.ts` is **new and pure — no Svelte** — and owns: quarter bucketing by `dt_start`, season-boundary detection, anchor resolution, next-upcoming, scope filtering, `registrationState()`, `countryCode()`, and the type split.

Two ordering hazards it must absorb rather than inherit:

- `fetchPriorSeasonEvents` (`api.ts:206`) sorts by `.order('txt_code')` while `fetchCalendarEvents` (`:172`) sorts by `.order('dt_start')`. Since `txt_code` orders `PEW10` before `PEW2`, the multi-season path arrives in an order that is neither chronological nor numeric. **`calendarQuarters.ts` sorts by `dt_start` itself and never trusts caller order**, pinned by a test that feeds deliberately shuffled input.
- **Next-upcoming is derived from the *filtered* set**, not assigned once — toggling scope must move the ring.

The multi-season load is a caller change, not a new query: volume is roughly 20 events per season, so a single up-front load is simpler than lazy-loading on boundary approach and removes the fetch-per-rotation problem entirely.

**There is no migration, no `vw_calendar` rebuild and no SQL in this work.** An earlier draft proposed `txt_nearest_hub` / `num_nearest_hub_km`; it was dropped on 2026-08-09 as the only unrequested item with no acceptance criterion attached. Raise it separately if wanted.

### 14 · The four-way type split is kept, and the fourth bucket is renamed

`slotTypeClass()` (`CalendarView.svelte:241-246`) already types events four ways, but the stylesheet paints `.slot.ppw.completed` and `.slot.mpw.completed` identically — **`MPW` is classified separately and then rendered the same**. The distinction was built and never cashed in.

Keep the four-way split in `calendarQuarters.ts` and let the barrel decide whether the fourth gets its own treatment:

| Bucket | Absorbs | Note |
| --- | --- | --- |
| `ppw` | domestic regular series, GP | |
| `mpw` | `MPW` | **kept distinct** even though nothing styles it yet |
| `pew` | EVF circuit | |
| `int` | `IMEW`, `IMSW`, `MEW`, `MSW`, `PSW` | **renamed** from the live `imew` |

Keeping `mpw` matters for the open past-season-anchor item, which asks for championships to be marked distinctly so finished seasons keep a focal point once next-upcoming has nothing to point at. That is not new machinery — it is styling a bucket the code has carried, unstyled, all along. Discarding the bucket would turn a styling decision into a prerequisite.

### 15 · Country flags are CSS, and depend on an enrichment pass

`CountryFlag.svelte` draws horizontal bands, vertical bands and offset crosses in CSS. **No emoji** — inconsistent on Android, absent on many devices — and **no image requests**, per ADR-007's CSP.

It has an unstated prerequisite: `txt_country` is free text today. Normalisation to ISO-3166 alpha-2 is a **one-time enrichment pass with human review of ambiguous cases, never a per-render web lookup**. `countryCode(raw)` returns `null` for unrecognised input so the component degrades to no flag and is not blocked on the pass completing.

This is why ADR-028 is amended. Its refresh contract lists `txt_location` and `txt_country` as **never refreshed** — a rule that exists to stop the scraper overwriting curated values, not to freeze the columns forever. A one-time curated enrichment write is a different act from a scraper refresh, and the never-refreshed rule continues to bind the scraper afterwards.

### 16 · What is removed, and what is carried unchanged

**Removed:**

| Removed | Why |
| --- | --- |
| Month-grouped event list | Replaced by the barrel; ADR-015 §2 superseded |
| Rolling-progress strip | The two-channel defect; ADR-018's UI consequence withdrawn |
| Season dropdown | The barrel owns season state (§4); the seam carries the code (§7) |
| Time filter (all / past / future) | The drum *is* the time control |
| Weapon filter | Dropped entirely — the data is not to be compressed |
| Tournament count on the card | Filled 103/103 and useless to read there; still loaded, still drives the barrel |
| `isActiveSeason` prop | Existed only to gate the strip (`:34`, `:269`); becomes a lie once the strip goes. Delete from the props interface, from `App.svelte:81`, **and** the derivation at `App.svelte:399` |

**Carried unchanged — deliberately, not by omission:**

- **The CERT/PROD environment footer.** `activeEnv` is `$bindable` and `App.svelte:379-380` derives `supabaseUrl` / `supabaseKey` from it, so pressing `PD` re-points the whole Supabase client at production. Four tests in `env-toggle.test.ts` mount `CalendarView` solely to drive this. Leaving `dualEnv` / `activeEnv` declared but unrendered compiles clean, passes `svelte-check`, and fails only at runtime as a silently missing control — the worst way for this one to fail. It is **deliberately temporary**: it retires when PROD moves off GitHub Pages to the WordPress CMS, together with both props and those four tests. Carry it across unchanged and **do not improve it**; the byte-identical second copy in `App.svelte:70-79` also stays, because hoisting it would add the footer to admin views that do not have it.
- **`getEventDisplayStatus()`** from `lib/eventStatus.ts` — already exhaustive over the lifecycle plus derived awaiting-results (ADR-037). `EventCard` consumes it unchanged; zero new work.
- **The two ADR-037 / ADR-077 data rules**, ported into `calendarQuarters.ts` verbatim: `CREATED` events hidden as dateless planning skeletons (`:264`), and the cancelled-event notice window of `dt_end + 7 days` (`:250-256`).

### 17 · Scroll behaviour

The page scrolls; the barrel is **not** pinned. Pinning ~250px of drum above every card on a 568px screen leaves under half the display for the thing the reader came for, and the barrel is not used continuously — you spin it, pick, then read.

## Alternatives considered

1. **Keep the timeline and just re-tune the strip's colours.** Rejected — the defect is two variables in one channel, so any palette inherits it. Re-tuning would have bought a nicer-looking version of the same unreadable encoding.
2. **Horizontal timeline** — this is what ADR-015 §2 explicitly rejected as "poor mobile", and the objection deserves an answer rather than a reversal. It was right about a *scrolling* horizontal timeline, where the viewport is a sliding window over an unbounded strip and the reader loses their place. The barrel is not that: it is **quantised** into quarters, three rows are visible at once with the focus always centred, and the seams keep absolute position legible. The mobile objection is met by measurement at the rejected breakpoint — 320px verified throughout, five panels flat and six fanning — rather than by assertion.
3. **Compress panels to fit the viewport.** Rejected — at 320px a compressed panel is illegible, which trades a visible overlap for an invisible failure. Overlap keeps every panel at full size and trades *visibility* for *size*, so a date fragment always survives.
4. **Shrink the drum to one row, or a flat carousel.** Rejected — the receded rows are what make the control legible as a continuum; one row is a dropdown with extra steps.
5. **Pin the barrel to the top.** Rejected on the 568px arithmetic in §17.
6. **A `CalendarFilters.svelte` component.** Rejected. It was sized to hold two controls, the scope segment and a weapon picker; the weapon filter is a settled removal, so one control is left and it goes inline in the orchestrator with the state it depends on. A judgment call, not a constraint — extract it if the scope control ever gains a second dimension.
7. **Per-weapon result-link labels.** Rejected as an ADR-040 violation; day labels replaced them.
8. **Retaining the weapon filter with a `localStorage` preference shared with the ranking tab's `BROŃ` selector.** Rejected with the filter itself; there is no preference left to persist.
9. **Nearest-hub / nearest-airport fields on the card.** Dropped 2026-08-09 (§13) — never requested, no acceptance criterion, and the sole reason this work would have needed a migration.
10. **Folding `MPW` into `ppw`** as the mock does, dropping the unused class. Rejected for the module (§14) — it would make the past-season-anchor decision a prerequisite instead of a styling choice.

## Consequences

- **Four new files:** `lib/calendarQuarters.ts`, `components/CalendarBarrel.svelte`, `components/EventCard.svelte`, `components/CountryFlag.svelte`. `CalendarView.svelte` becomes an orchestrator. **Not five** — `CalendarFilters.svelte` is not built.
- **Test triage spans two files and is not optional.** `CalendarView.test.ts` holds 49 tests and `env-toggle.test.ts` a further 4 mounting the same component — **53 in scope**. Every one gets a decision recorded in one of three buckets — **move** (behaviour survives), **rewrite** (behaviour deliberately changed), **delete** (assertions about removed DOM) — and no test is deleted without recording its bucket. The *rewrite* bucket is currently empty; see §9.
- **Three of those deletions retire an ADR-018 consequence.** R.23, R.24 and R.25 (`CalendarView.test.ts:374`, `:390`, `:401`) assert `.rolling-progress`, `.slot`, and `.slot.completed` / `.slot.planned`. They are the recorded verification of ADR-018's calendar UI, so ADR-018 must be amended in the same change rather than left pointing at deleted tests.
- **Carry-over is not affected, and ADR-018's calendar description is corrected rather than merely withdrawn.** ADR-018 describes the calendar strip as three-state — green ✓ completed, amber `↩` carried, grey — empty. **Only two of those states were ever built.** `positionSlots` (`CalendarView.svelte:268`) computes a single boolean, `completed: e.enum_status === 'COMPLETED'`; the template renders `class:completed` / `class:planned`; the CSS at `:638-656` covers exactly those two per type bucket. The word *carried* and the `↩` glyph do not appear in `CalendarView.svelte`, and nothing in it reads prior-season results — the strip is named `rolling-progress` while displaying no rolling data. Carry-over's actual surface is `DrilldownModal.svelte:49-104` (the `↩` banner, `.carried-row`, striped swatches, legend), driven by `bool_has_carryover` on the ranking row types (`types.ts:95`, `:105`). It is a ranking concept: a fencer's points from last season's event at the same position stand in until this season's event at that position is scored. **A calendar has no carried state to lose** — an event either takes place or it does not. So ADR-018's amendment withdraws the calendar UI consequence *and* corrects a three-state claim that never matched the implementation, which is a documentation defect predating this redesign.
- **Two live defects are reported, not silently fixed:** the `tournaments_count` pluralisation defect (§12), and the duplicated env footer between `App.svelte` and `CalendarView.svelte` (§16 — leave it, it retires with the WordPress migration).
- **One finding to verify, not fix:** `ce/CalendarElement.svelte` derives `demo ? MOCK_CALENDAR_EVENTS : []`, meaning the non-demo embed renders empty. Confirm how the production `spws-calendar` element is actually fed before changing anything; if it is genuinely unwired that is a separate report. Note also that the embed renders **no header** — `CalendarElement` mounts `CalendarView` alone, so the hamburger, wordmark and language toggle are app-only chrome. Should that change, the logo's `src="SPWS-logo.png"` is document-relative and would resolve against the host page and 404.
- **`SCORED` label dependency.** ADR-077 recorded that the display map omits `CREATED` and `SCORED`, both rendering as "Planned", marked as a fix. `CREATED` is moot here since the barrel hides it, but `SCORED` is a real state on the forward spine and the card must label it. Verify against `eventStatus.ts` before assuming ADR-037's helper is complete.
- **Zero DB impact.** No migration, no view rebuild, no `types.ts` extension, no `plpgsql-check` run.
- **Documentation:** register in specification Appendix C; update `doc/handbook/product/product-surfaces.html`, `doc/handbook/subsystems/events-and-registration.html`, and `doc/handbook/reference/codebase-map.html`. RTM check for requirements touching calendar presentation — ADR-030's FR-90/FR-91 and ADR-079's FR-120–FR-130 keep their wording but the test IDs they cite move.

## Open items

Both remaining items land in `resolveAnchorQuarter()`, which is why that function is written **last** in the pure module.

1. **What the card opens on** — next upcoming, most recent result, or time-sensitive. **Recommendation: time-sensitive** — the result for seven days after an event ends, then the next upcoming. The Monday after a competition weekend everyone wants results; three weeks later nobody does. The seven-day window already exists in the codebase for cancelled-event notices, so it is not a new concept to explain. *The mock opens on next-upcoming because that was the simplest thing to demonstrate; that is not a decision.*
2. **Past-season anchor** — finished seasons have no next-upcoming event, so the drum loses its focal point and rows read flat. **Recommendation:** mark championships (`MPW`, `MŚW`, `MEW`) distinctly using the `mpw` and `int` buckets §14 preserves, so past rows keep structure. Marking events the viewer competed in would be better but is impossible on a public embed with no viewer identity.

## Verification

`npm run check` and `svelte-check` on every changed `.svelte` and `.ts`; `npx vitest run` for the full frontend suite. Browser preview via the `frontend-ce-dev` launch config on port 5299 (`index.ce.html`), at 320, 360 and 390px.

**Measure, do not eyeball** — most of the geometry findings in this design were caught that way and would have passed a glance:

- five panels flat at 320px, six fanning; no content spilling past a panel border, and the selected panel's outline not clipped by the row's scroll container
- the selected panel's month in full and untruncated in **both** languages — `października` is the widest
- rotation across a season boundary updates season state
- the `PPW | +EVF` control appears only when `show_evf_toggle_calendar` allows it, **and** turning it off actually removes EVF events rather than only hiding the buttons
- the next-upcoming ring moves when scope is toggled
- all three fee lines with the right currency, and no tier on a single-weapon event
- the entry-list link present on a future event whose deadline has passed, and absent on a cancelled one
- copy-to-clipboard writing the full composed address, with the icon confirming and reverting
- `EN | PL` switching every string, including plural forms at counts of 1, 2 and 5
- the CERT/PROD footer still present and still switching environments

A 320px screenshot placed beside the mock is the acceptance check.

## Amendment (2026-08-28) — a third chip on the card, and nothing on the barrel

The event card's two-chip line gains a third chip when EVF has moved a still-future `PLANNED` event: *ZMIANA DATY z 12/12/2026*, naming the first date EVF published.

The barrel is deliberately untouched. This ADR already spends hue on event type, fill on completion and ring on next-upcoming; a fourth channel would crowd the overview that is scanned first. The signal appears on the card the moment the event is opened. See [Event status lifecycle](../handbook/reference/event-status-lifecycle.html).

## Amendment (2026-09-02) — the dataset the drum is entitled to, and what a failure inside it may cost

Two halves of one defect, found on PROD.

§4 said the drum spans every season and rolls back to the start of history with
no season clamp. `api.ts` carries that as a written warning above
`fetchAllCalendarEvents`: the season-scoped `fetchCalendarEvents` cannot feed
it. Six sites in `App.svelte` did exactly that anyway — the create, update,
status and delete handlers, and both admin-list loaders — so **saving any event
silently cut the calendar down to the selected season**, 66 month rows to 10 on
PROD data. The decision is now expressed as one function, `reloadCalendar()`,
which is the only thing permitted to assign `calendarEvents`; the season-scoped
query keeps its legitimate callers, the prior-season and carry-over pickers,
and the admin list still scopes its own tournament fetch by season.

The narrowing was survivable on its own. What made it fatal is that
`CalendarBarrel` holds the selection as an **index into the focused row's
events**, and the events can be replaced under it. A month that had held four
events came back holding one while the fourth was still selected; `midLayout`
indexed the row with that stale index under a non-null assertion, and
`cityOf(undefined)` threw `Cannot read properties of undefined (reading
'txt_location')`. The selection is now read through `liveSelected`, clamped to
the row it is actually being read against, by every consumer that indexes it —
the layout, the scroll target, the caret and the tile's own selected state.

**The severity is the part worth recording.** The throw came out of a
`$derived`, which tears down the component tree, and the barrel shares that tree
with the entire application. The page was not frozen: on the live PROD session a
100 ms heartbeat showed no gap and a capture-phase listener recorded the user's
clicks arriving normally. There was simply nothing left listening to them, so
the header, the navigation and the hamburger died alongside the calendar and
only a reload brought them back. A calendar defect is now contained by a
`<svelte:boundary>` around the calendar view, which renders the failure and its
message in place and leaves the rest of the application working.

One testing consequence, because it is why 700 tests missed this. `midLayout`
returns early while `available <= 0`, and jsdom reports every `clientWidth` as
0 — so the barrel's whole geometry branch, and all of its indexing arithmetic,
was unreachable in the suite. CB.30–CB.32 stub `clientWidth` to enter that
branch deliberately and drive five data transitions through it. Anything added
to that branch should be tested the same way.

## Amendment (2026-08-29) — monthly seams, an inverted palette, and a cylinder

Everything below was measured against the live PROD pool (114 events, 91 dated, 2022-01-08 → 2027-06-18), seeded into LOCAL and verified on both sides, not inferred from the code. Source: `doc/plans/kalendarz-mocki-2026-08-29.html` (live mocks + the locked decision table).

### A · The drum buckets by month, not quarter

**§2 and §4 are superseded in their bucketing.** Quarters overflow: on PROD **10 of 19 quarter rows hold five or more events, the worst nine**. Nine 48px tiles need 456px and cannot fit a 320px viewport, which is the sole reason §5's overlap-and-fan machinery exists. Monthly gives **48 active rows, worst row four, none over four**. PZSz senior events are being added, which makes quarters worse and months merely fuller.

`layoutRow()` and §5 are **kept**, not retired: PZSz events could push a month to six or eight tiles (303–399px), still over 320px. Overlap stops being the common case rather than stopping being needed.

The seam engraves the **full month name**, localised. Polish needs two forms and the locale files carry both: the seam names a month standing alone and takes the **nominative** (`month_N`, "Wrzesień"), while a tile prints a day beside it and takes the **genitive** (`cal_month_N`, "26 września"). Using one form for both is visibly wrong in Polish and invisible in English — ADR-063's concern, applied to a new surface.

### B · Time drives the palette; the past recedes

**§1 is superseded in its channel assignment.** §1 gave hue to event type and fill to completion, and `CalendarBarrel.svelte` implemented fill as `enum_status === 'COMPLETED'`. On PROD that is **67 of 114 events**, so the entire colour budget went to the finished majority while the events a fencer can still enter rendered as plain white.

The channels are reassigned:

| Channel | Was | Is |
| --- | --- | --- |
| Body fill | completion (`COMPLETED`) | **time** — grey once past, tinted while ahead, saturated when imminent |
| Hue | event type | **time**, on the body; type moves to the edge |
| Top edge | — | **organizer**, 3px, non-chromatic elsewhere |
| Ring | next upcoming | unchanged |
| Outline | selected | unchanged |

Time state is decided by **date, not status**, and that distinction is the point: an event can sit un-ingested for weeks and still read `PLANNED`, so a status-driven palette showed a competition held in January as though it were ahead. A finished event keeps its colour for **thirty days** — results arrive late and a competition stays worth looking at for about a month — then goes neutral. An event within **seven days** of starting is emphasised. An event with no `dt_start` is treated as ahead, never greyed, because it cannot be placed.

A past tile loses its type hue deliberately. Type stays legible in the label, and past events are the ones nobody scans.

### C · The drum is a true cylinder

**§2's `translateY` rotation is superseded.** Rows are placed on the surface of a cylinder — `rotateX(i·θ) translateZ(R)`, with `R = (rowHeight/2) / tan(θ/2)` — and the drum rotates as one body. Foreshortening at the rim, the compression of spacing toward the horizon, occlusion and the horizon itself fall out of the perspective projection instead of being drawn. At θ = 26° the drum carries **seven rows** (R = 178px; a receded row measures 69px against the focused row's 82px). Time runs **upward**: the future sits above the focused row, the past below, inverting the flat drum's `.ln.up = active − 1`.

Two failures are recorded because both cost time and neither is obvious:

1. **A drum whose DOM is rebuilt on rotation cannot animate at all.** A CSS transition needs the same nodes on both sides of the change, so re-rendering rows on rotate makes them snap while the drum slides. Row angles are absolute positions on the cylinder and are written once; only the drum's transform changes.
2. **Rotation is `−active × θ`, which reaches `−1456deg` by row 56.** With the transition live from the first paint the drum spins through four complete turns before settling. Animation is enabled only after the opening frame — by timeout, not `requestAnimationFrame`, which never fires in a background tab and would strand the transition permanently off.

Momentum overshoot and motion blur were both built and both rejected: the geometry was never the problem, the motion effects layered on it were.

### D · Quiet months render, but the drum never rests on one

Monthly granularity materialises **18 empty rows of 66** on the current pool, against a handful at quarterly. They are rendered, so a gap in a season stays visible and the time axis stays linear, but `settleRow()` carries the rotation on in the direction of travel until it reaches a month that holds something, and reverses at the end of the drum rather than falling off. `resolveAnchorRow()` uses it too, which is a deliberate change from §4: the quarter barrel parked on an empty row so "now" stayed centred, and at monthly granularity that shows the user nothing.

### E · Country flags are the complete circular set

**§15 is superseded.** §15 chose CSS geometry drawn from four primitives, with emblem-bearing flags **deliberately absent** rather than approximated and four stripe-only pairs (Italy/Mexico, Ireland/Côte d'Ivoire, Romania/Chad, Monaco/Indonesia) acknowledged as indistinguishable.

That approach produced **wrong flags, silently**. Three of about sixty-six were found by eye in one sitting, each on a country the calendar actually shows:

- **`CH` rendered as a Danish cross.** The Swiss cross is free-standing and inset, arms stopping short of the edges; and the flag is **square**, so a 19×13 box also gave it unequal 3.1px/4.6px arms. Live on PEW10e in Lausanne.
- **`GE` rendered as England** — a plain red cross on white. Georgia's four Bolnisi crosses are the only thing separating them. Live on MSW in Tbilisi.
- **`GR` rendered as nine bare stripes** with its canton missing, which in a circle is indistinguishable from any other striped flag.

All **265 ISO-3166 alpha-2 countries** are now drawn correctly, from `circle-flags` (MIT), generated into an inline module at 168KB raw / **38KB gzipped**. Coverage matters because championships move: the calendar already reaches Toronto and Tbilisi, and scoping the set to countries currently in the database would fail the first time an event goes somewhere new.

Still **inline**, and §15's constraint is upheld even though its stated reason was wrong. The old component cited ADR-007 for a CSP that blocks fetched assets; **ADR-007 is "Shadow DOM (Implemented M8)" and says nothing about CSP, and no CSP exists in the repository.** The real constraint is that `vite.config.ce.ts` sets no `base`, so an emitted asset URL resolves against the host page inside a custom element on a third-party site and 404s — the defect already latent in `SPWS-logo.png`.

Circular removes the aspect-ratio problem entirely, so there is no box to force a square flag into.

### F · The card gains a surface, and keeps every block

**§8's content and ordering are untouched** — all ten blocks remain, in order, with their type sizes unchanged. Only the surface changes: a layered elevation shadow, a solid 3px top edge in the selected tile's organizer colour so the card reads as extruded from it, and a brief tilt when the content swaps.

Two treatments were built and rejected. A **top-lit surface gradient** shifted contrast from top to bottom behind a lot of small text — fee keys, chips, pills — and cost legibility for depth the shadow already supplied. An **inner bevel** added nothing once the shadow existed. There are **no gradients on the card**: the top edge began as a wash falling from the top and is a solid bar precisely because that was the rejected gradient under another name.

The status chip follows the inverted palette — **`COMPLETED` renders grey, not green**, because a green chip would contradict a greyed tile. The registry chip carries the organizer hue **outlined** while the status chip is **filled**: hue alone could not separate them, since an SPWS event that is `PLANNED` renders two adjacent chips in the same green and reads as one blob. A cancelled event strikes its title and dims its content **element by element**, not by an opacity on the card — opacity on a parent applies to every descendant, so a blanket dim would mute the highlighted cancelled chip, which is the one thing that must not be missed.

The location line is no longer gated on a parsed city. `txt_location` sometimes holds a venue string the scraper wrote into it, which `splitLocation()` classifies as venue-only; gating the row on `city` therefore dropped the **flag and the country** with it, leaving a Budapest event with no indication of where it was.

### G · A live-registration dot on the tile

A dot marks an event whose registration is open — from the moment a registration URL exists until `dt_end`. **Relates to [ADR-030](030-event-registration-url-deadline.md).**

The URL is the signal because it is not incidental: `EventManager`'s "Rejestracja SPWS" checkbox **derives** `url_registration` (and `url_entry_list`) when ticked and **clears both to `''`** when unticked, so a non-empty URL means an administrator opened registration. A new `dt_registration_open` column was built for this and **reverted**: it duplicated a fact the schema already carried.

The window closes at `dt_end`, **not** at `dt_registration_deadline`. That is deliberate and it means the dot **outlives the card's registration pill**, which ADR-030's `registrationState()` retires at the deadline. For PPW1-2026-2027 that is a week. The dot marks a live registration/participation window; the pill marks whether the link is still usable.

### H · A tap names an event, and rotation keeps it

**§6 is refined.** §6 said tapping a receded row rotates it to centre and tapping a panel on the focused row selects that event. It left the third case implicit, and the implementation resolved it badly: tapping a *panel on a receded row* rotated the row and then selected the row's **default** — the ringed next-upcoming, else the first event.

That discards the one thing the tap had already said. Aiming at the third event in a row and landing on the first is a small, repeated annoyance that costs a second tap every time. A panel tap now carries **that panel** through the rotation.

Tapping the row body still uses the default, because no event was named there. The distinction is between "show me this month" and "show me this event".

### I · The date leads the card, and the caret points at the right tile

Two corrections from live testing.

**The date is the card's headline.** §8 orders the card by what a fencer acts on and puts identity — date, code, name, place — first, but the date rendered at 11px in the secondary colour: the *smallest* text on the card, quieter than the fee keys. It is the first thing anyone checks, so it is now 17px/700 in the primary colour, larger than the event name.

**`PANEL_W` and the stylesheet had drifted apart, and the caret paid for it.** The constant stayed at 48 while `.ln.mid .p` was widened to 68px — a change monthly seams made affordable, since a row holds at most four events where a quarter held up to nine. Nothing looked wrong, because flex does the real layout; but the caret that points from the card up to its tile is positioned from these numbers, so it sat about 20px left of its target and drifted further across the row. `PANEL_W` is now 68 and `CARET_HALF` 8, each carrying a comment naming the CSS rule it mirrors, and a test asserts the **literal** rather than the constant — comparing `PANEL_W` to itself would pass while the stylesheet said something else, which is precisely how this got through.

Retuning that constant moved the overlap threshold: at 320px **four panels now sit flat and five fan**, where five sat flat before. That is a better fit than it sounds — the busiest month in the entire PROD pool holds exactly four events, so a monthly row fits flat and fanning becomes the exception rather than the rule it was at quarterly granularity.

The caret also takes the selected event's organizer hue now, matching the card's coloured top edge, so the two read as one edge tapering to a point. It was drawn in `--surface-1` — the card's own background — which against the page is a pale triangle sitting directly above a 3px coloured edge, and the element tying the two halves of the calendar together went unnoticed.

### J · Weekdays on the date, and a way back to the opening row

**Weekdays sit inline, before their own day number** — `sob 26 – niedz 27 września 2026`. A stacked line aligned under each number was considered and rejected: it only expresses the two-day case. MSW Tbilisi runs **9–13 October, five days behind two numbers**, and six events in the pool cross a month boundary, so there is nothing stable to align to. Column alignment would also depend on glyph widths, and `sob`/`niedz` are nothing like `Sat`/`Sun`. Inline degrades correctly everywhere and names the endpoints honestly: Tbilisi reads `pt 9 – wt 13`, a Friday-to-Tuesday championship rather than an implied weekend. Seven short weekday forms were added per language (`cal_dow_short_1..7`, Monday-first).

The header was re-sized to hold this on one row inside a 320px card: the date to 16px, the code pill to 8.5px, measured against the longest code in the upcoming pool (`PEW11efs-2026-2027`, 18 characters). The code is reference detail that also appears on the tile, so the pill is what gave way.

**A jump control resolves the drum-depth question** left open above. It appears **only when the focused row is not the opening row**, so it costs nothing in the common case and its appearance is itself the signal that you have drifted. **The arrow carries direction and distance, in three states.** A single fixed right-arrow pointed at nothing: the drum travels vertically. The glyph now names the move — **up** when the anchor is ahead of the focus and the drum must roll up to reach it, **down** when the focus has run two or more rows into the future, and **left** at exactly one row into the future, where the anchor is the adjacent row and the reading is "it is right here" rather than a direction of travel. It is ONE path rotated per state, not three paths: three would drift apart in stroke weight and cap geometry the first time any one of them was retouched.

**Going forward, the control leaves the drum and pins to the viewport's lower edge**, holding one position instead of drifting with the focus at every step. It does NOT parent to the lowest seam's row, which was tried and measured: that row sits at `d = -3`, so it inherits `rowOpacity` = cos(78°) × 0.9 ≈ **0.19**, and opacity applies to the whole subtree, so a child cannot opt out — and worse, the row projects to y ≈ 269 in a 246px viewport, about 23px past the bottom edge, where `overflow: hidden` removes it outright. The control was not faint, it was **absent**. Pinned, it occupies the same visual position at full opacity, and it no longer needs a row to exist three below the focus, which near the start of the drum there is not.

Going back it still rides the adjacent upper seam (`dn`, `active + 1`), which renders on screen at 0.81 opacity: that is already the shortest possible hop, with nothing to steady.

The arrow is an **`aria-hidden` SVG**, not a character in the translated string: the button's accessible name stays the label alone, and a translator never has to carry the glyph through. It is drawn rather than typed because `→` renders at whatever weight and baseline the system font chooses — it sat visibly low against the 11px label and did not match its stroke. The path takes `currentColor`, so it follows the accent across themes, and the button is laid out as an `inline-flex` row so the icon centres on the label instead of depending on a hand-tuned baseline nudge.

It targets **`anchorIndex`, not the month containing today**, and that distinction is the whole point: today's month is frequently empty — August 2026 holds no events at all — and the drum never rests on an empty row, so a literal "jump to today" would land somewhere it immediately rolls off. It is labelled by **what the destination is** — "Najbliższe zawody" / "Nearest competition" (`calendar_jump_to_next`) — rather than by the month it lands on. Naming the month was the first form and it has two faults: it makes the reader decode a date to work out where the button goes, and the month is not stable — it changes under the reader as the pool moves. Naming it "today" is not available either, for the reason just given: a button reading "today" that lands you in September would be a small lie. Naming the destination by what it IS avoids all three: it is accurate whatever the pool holds, and it says what the button does.

The jump is **instant**. Crossing forty rows is over a thousand degrees, nearly three full turns, the same failure the opening frame avoids. And it stops the tap reaching the row beneath it, which is itself a target that rotates one step — without that, the jump and a single step would fight over the same tap, precisely when someone is already lost.

### What this amendment does *not* settle

**Open item 1 is still open.** It asks what the card should *open* on and proposes a seven-day result window before falling back to next-upcoming. The thirty-day window introduced above governs the **palette**, not the anchor; `resolveAnchorRow()` still resolves to next-upcoming. The two windows are unrelated and should not be conflated.

**Open item 2 is still open** — past-season anchoring is unchanged.

Two further items are open and recorded in the plan rather than here, being product questions rather than architecture: whether the committed seed dump (`seed_prod_latest.sql`, still the 8 August snapshot) should be refreshed. The jump-to-today question is resolved in §J.

### Verification

| Gate | Result |
| --- | --- |
| vitest | 655 passing, 45 files |
| pgTAP | 849 passing, 68 files |
| svelte-check | 0 errors |
| Bundle | 313KB gzipped, of which flags are 38KB |
| Live | verified against the seeded PROD pool at LOCAL, not only in tests |

`lib/calendarQuarters.ts` is renamed `lib/calendarMonths.ts`; `Quarter` becomes `MonthRow`; `buildQuarters`/`quarterKeyOf`/`resolveAnchorQuarter` become `buildMonths`/`monthKeyOf`/`resolveAnchorRow`. New exports: `settleRow()`, `eventTimeState()`, `isRegistrationOpen()`. `CountryFlag.svelte` loses ~350 lines of hand-drawn geometry and its test suite is replaced rather than ported — 18 of its 22 tests asserted primitives that no longer exist.
