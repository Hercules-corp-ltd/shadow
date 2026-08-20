/**
 * The slide-in log panel.
 *
 * ## Why it scrolls at all
 *
 * The page consumes every wheel event and preventDefaults it — that is what
 * makes it a fixed viewport with a scroll position we own. A panel with real
 * overflow inside that arrangement is dead on arrival unless something lets go,
 * so the scroller here carries `data-native-scroll` and the loop's wheel and
 * touch handlers bail out when the event starts inside it. No open/close
 * signalling between the two: the DOM answers the question.
 *
 * ## What it contains
 *
 * Real commits, generated from git history by assets/gen/changelog.mjs. A
 * hand-written list of milestones would have been easier and worth nothing —
 * the point of a build log is that it is evidence, not that it exists.
 *
 * ## The dialog behaviour, which is most of the work
 *
 * A panel that opens is easy. A panel that opens *and can be left* takes: Esc,
 * a close button, a click on the scrim, focus moved in on open and returned to
 * whatever opened it on close, focus kept inside while it is open, and
 * `aria-hidden` on everything behind so a screen reader does not wander into
 * the page underneath. All of that is here and none of it is optional.
 */

const DATA_URL = 'data/changelog.json';

export function createPanel({ onOpen, onClose } = {}) {
  let root = null;
  let scroller = null;
  let opener = null;
  let loaded = false;
  let open = false;

  function build() {
    root = document.createElement('div');
    root.className = 'panel';
    root.setAttribute('role', 'dialog');
    root.setAttribute('aria-modal', 'true');
    root.setAttribute('aria-label', 'Build log');
    root.hidden = true;
    root.innerHTML = `
      <div class="panel__scrim" data-close></div>
      <aside class="panel__sheet">
        <header class="panel__head">
          <span class="panel__kicker">Shadow · Build log</span>
          <button class="panel__close" type="button" data-close aria-label="Close the build log">
            <span class="panel__esc">Esc</span>
            <svg viewBox="0 0 16 16" aria-hidden="true"><path d="M4 4l8 8M12 4l-8 8" stroke="currentColor" stroke-width="1.4" fill="none" stroke-linecap="round"/></svg>
          </button>
        </header>
        <div class="panel__title">
          <h2>Every commit</h2>
          <p class="panel__count" data-count>Loading…</p>
        </div>
        <div class="panel__scroll" data-native-scroll tabindex="0" data-list>
          <ol class="log" data-log></ol>
          <p class="panel__end">End of log — github.com/Hercules-corp-ltd/shadow</p>
        </div>
      </aside>`;
    document.body.append(root);
    scroller = root.querySelector('[data-list]');

    root.addEventListener('click', (e) => {
      if (e.target.closest('[data-close]')) close();
    });
    root.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') { e.stopPropagation(); close(); return; }
      if (e.key === 'Tab') trapFocus(e);
    });
  }

  function trapFocus(e) {
    const focusables = root.querySelectorAll('button, [href], [tabindex]:not([tabindex="-1"])');
    if (!focusables.length) return;
    const first = focusables[0];
    const last = focusables[focusables.length - 1];
    if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
    else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
  }

  async function load() {
    if (loaded) return;
    loaded = true;
    let data;
    try {
      const res = await fetch(DATA_URL);
      if (!res.ok) throw new Error(String(res.status));
      data = await res.json();
    } catch (err) {
      // Say what happened. An empty log and an unreachable one are different
      // claims, and this whole project has spent a week on that distinction.
      root.querySelector('[data-count]').textContent = 'The log could not be loaded.';
      loaded = false;
      return;
    }

    const fmt = (iso) => {
      const [y, m, d] = iso.split('-');
      return `${d} ${['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'][+m - 1]} ${y.slice(2)}`;
    };

    root.querySelector('[data-count]').textContent =
      `${data.count} commits · since ${fmt(data.since)}`;

    const list = root.querySelector('[data-log]');
    const frag = document.createDocumentFragment();
    let lastDate = null;
    for (const e of data.entries) {
      const li = document.createElement('li');
      li.className = 'log__row';
      const showDate = e.date !== lastDate;
      lastDate = e.date;
      li.innerHTML = `
        <span class="log__date">${showDate ? fmt(e.date) : ''}</span>
        <span class="log__body">
          <span class="log__title"></span>
          ${e.blurb ? '<span class="log__blurb"></span>' : ''}
          <span class="log__hash">${e.hash}</span>
        </span>`;
      // textContent, not innerHTML — commit subjects are arbitrary text and
      // one of them will eventually contain a angle bracket.
      li.querySelector('.log__title').textContent = e.title;
      if (e.blurb) li.querySelector('.log__blurb').textContent = e.blurb;
      frag.append(li);
    }
    list.append(frag);
  }

  function openPanel(fromEl) {
    if (open) return;
    if (!root) build();
    opener = fromEl || document.activeElement;
    open = true;
    root.hidden = false;
    // Force a reflow so the transition has a start state to animate from,
    // rather than waiting a frame for it.
    //
    // The obvious version of this is requestAnimationFrame, and it is a trap:
    // rAF does not run in a page the browser considers hidden or heavily
    // throttled, so the panel would unhide and then simply never slide — stuck
    // off-screen with focus already moved into it and everything behind marked
    // aria-hidden. Reading offsetWidth is synchronous and cannot not happen.
    void root.offsetWidth;
    root.classList.add('is-open');
    document.body.classList.add('panel-open');
    for (const n of document.body.children) {
      if (n !== root && !n.hasAttribute('aria-hidden')) {
        n.setAttribute('aria-hidden', 'true');
        n.dataset.panelHid = '1';
      }
    }
    load();
    root.querySelector('.panel__close').focus();
    onOpen?.();
  }

  function close() {
    if (!open) return;
    open = false;
    root.classList.remove('is-open');
    document.body.classList.remove('panel-open');
    for (const n of document.querySelectorAll('[data-panel-hid]')) {
      n.removeAttribute('aria-hidden');
      delete n.dataset.panelHid;
    }
    const done = () => { if (!open) root.hidden = true; };
    setTimeout(done, 320);
    opener?.focus?.();
    onClose?.();
  }

  return {
    open: openPanel,
    close,
    get isOpen() { return open; },
  };
}
