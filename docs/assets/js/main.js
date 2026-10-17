/* La Casa Bella — site interactions (no dependencies) */
(function () {
  'use strict';

  var doc = document;
  var root = doc.documentElement;
  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  var $ = function (sel, ctx) { return (ctx || doc).querySelector(sel); };
  var $$ = function (sel, ctx) { return Array.prototype.slice.call((ctx || doc).querySelectorAll(sel)); };

  /* ---------- Header: scrolled + hide on scroll down ---------- */
  function initHeader() {
    var header = $('[data-header]');
    if (!header) return;
    var lastY = window.scrollY;
    var ticking = false;

    function update() {
      var y = window.scrollY;
      header.classList.toggle('is-scrolled', y > 24);
      var hide = y > 480 && y > lastY + 4 && !header.classList.contains('menu-open');
      var show = y < lastY - 4 || y <= 480;
      if (hide) { header.classList.add('is-hidden'); root.classList.add('is-header-hidden'); }
      else if (show) { header.classList.remove('is-hidden'); root.classList.remove('is-header-hidden'); }
      lastY = y;
      ticking = false;
    }
    window.addEventListener('scroll', function () {
      if (!ticking) { window.requestAnimationFrame(update); ticking = true; }
    }, { passive: true });
    header.addEventListener('focusin', function () { header.classList.remove('is-hidden'); root.classList.remove('is-header-hidden'); });
    update();
  }

  /* ---------- Mobile menu ---------- */
  function initMenu() {
    var toggle = $('[data-menu-toggle]');
    var menu = $('[data-menu]');
    var header = $('[data-header]');
    var label = $('[data-menu-label]');
    if (!toggle || !menu) return;
    var open = false;
    var closeTimer;

    function focusables() {
      return [toggle].concat($$('a[href], button:not([disabled])', menu));
    }
    function setOpen(state) {
      if (state === open) return;
      open = state;
      clearTimeout(closeTimer);
      toggle.setAttribute('aria-expanded', String(open));
      label.textContent = open ? 'Close' : 'Menu';
      header.classList.toggle('menu-open', open);
      doc.body.classList.toggle('is-locked', open);
      if (open) {
        menu.hidden = false;
        // force reflow so the clip-path transition runs
        void menu.offsetWidth;
        menu.classList.add('is-open');
        var first = $('a', menu);
        if (first) first.focus({ preventScroll: true });
      } else {
        menu.classList.remove('is-open');
        closeTimer = setTimeout(function () { menu.hidden = true; }, reduceMotion.matches ? 0 : 700);
        toggle.focus({ preventScroll: true });
      }
    }
    toggle.addEventListener('click', function () { setOpen(!open); });
    menu.addEventListener('click', function (e) { if (e.target.closest('a')) setOpen(false); });
    doc.addEventListener('keydown', function (e) {
      if (!open) return;
      if (e.key === 'Escape') { e.preventDefault(); setOpen(false); return; }
      if (e.key === 'Tab') {
        var items = focusables();
        var i = items.indexOf(doc.activeElement);
        if (e.shiftKey && (i <= 0)) { e.preventDefault(); items[items.length - 1].focus(); }
        else if (!e.shiftKey && i === items.length - 1) { e.preventDefault(); items[0].focus(); }
      }
    });
    window.matchMedia('(min-width: 1080px)').addEventListener('change', function (mq) { if (mq.matches) setOpen(false); });
  }

  /* ---------- Reveal on scroll ---------- */
  function initReveal() {
    var items = $$('.reveal, .reveal-media, [data-lines]');
    if (!('IntersectionObserver' in window) || reduceMotion.matches) {
      items.forEach(function (el) { el.classList.add('is-visible'); });
      return;
    }
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          io.unobserve(entry.target);
        }
      });
    }, { rootMargin: '0px 0px -8% 0px', threshold: 0.12 });
    items.forEach(function (el) { io.observe(el); });

    // Safety net: never leave content hidden (e.g. print, very tall screens)
    window.addEventListener('beforeprint', function () { items.forEach(function (el) { el.classList.add('is-visible'); }); });
  }

  /* ---------- Hero load state ---------- */
  function initHero() {
    var hero = $('[data-hero-section]');
    if (!hero) return;
    var img = $('img', hero);
    var done = function () { hero.classList.add('is-loaded'); };
    if (!img || img.complete) requestAnimationFrame(done);
    else { img.addEventListener('load', done); img.addEventListener('error', done); }
  }

  /* ---------- Subtle parallax ---------- */
  function initParallax() {
    var els = $$('[data-parallax]');
    if (!els.length) return;
    var mq = window.matchMedia('(min-width: 900px)');
    var ticking = false;
    function update() {
      ticking = false;
      if (reduceMotion.matches || !mq.matches) { els.forEach(function (el) { el.style.transform = ''; }); return; }
      var vh = window.innerHeight;
      els.forEach(function (el) {
        var host = el.parentElement;
        var r = host.getBoundingClientRect();
        if (r.bottom < -100 || r.top > vh + 100) return;
        var speed = parseFloat(el.getAttribute('data-parallax')) || 0.1;
        var progress = (r.top + r.height / 2 - vh / 2) / vh;
        el.style.transform = 'translate3d(0,' + (progress * speed * -100).toFixed(2) + 'px,0)';
      });
    }
    function onScroll() { if (!ticking) { ticking = true; requestAnimationFrame(update); } }
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);
    update();
  }

  /* ---------- Service index (home) ---------- */
  function initServices() {
    var wrap = $('[data-services]');
    if (!wrap) return;
    var rows = $$('[data-service]', wrap);
    var imgs = $$('.service-stage__img', wrap);
    function activate(i) {
      rows.forEach(function (r, n) { r.classList.toggle('is-active', n === i); });
      imgs.forEach(function (im, n) { im.classList.toggle('is-active', n === i); });
    }
    rows.forEach(function (row, i) {
      row.addEventListener('mouseenter', function () { activate(i); });
      row.addEventListener('focusin', function () { activate(i); });
    });
  }

  /* ---------- Photo rails ---------- */
  function initRails() {
    $$('[data-rail]').forEach(function (rail) {
      var controls = $('[data-rail-controls="' + rail.getAttribute('data-rail') + '"]');
      if (!controls) return;
      var prev = $('[data-rail-prev]', controls);
      var next = $('[data-rail-next]', controls);
      function step() { var item = rail.firstElementChild; return item ? item.getBoundingClientRect().width + 20 : 300; }
      function sync() {
        var max = rail.scrollWidth - rail.clientWidth - 2;
        prev.disabled = rail.scrollLeft <= 2;
        next.disabled = rail.scrollLeft >= max;
      }
      var behavior = reduceMotion.matches ? 'auto' : 'smooth';
      prev.addEventListener('click', function () { rail.scrollBy({ left: -step() * 1.5, behavior: behavior }); });
      next.addEventListener('click', function () { rail.scrollBy({ left: step() * 1.5, behavior: behavior }); });
      rail.addEventListener('scroll', function () { requestAnimationFrame(sync); }, { passive: true });
      rail.addEventListener('keydown', function (e) {
        if (e.key === 'ArrowRight') { e.preventDefault(); next.click(); }
        if (e.key === 'ArrowLeft') { e.preventDefault(); prev.click(); }
      });
      window.addEventListener('resize', sync);
      sync();
    });
  }

  /* ---------- Gallery: filters + lightbox ---------- */
  function initGallery() {
    var grid = $('[data-gallery]');
    if (!grid) return;
    var items = $$('.gallery-item', grid);
    var buttons = $$('[data-filter]');
    var empty = $('[data-gallery-empty]');
    var status = $('[data-gallery-status]');
    var aliases = { staycations: 'stay', 'the-place': 'place', events: 'celebrations' };
    var labels = { all: 'all photographs', place: 'The Place', stay: 'Staycations', celebrations: 'Celebrations', catering: 'Catering' };
    var visible = items.slice();

    function apply(filter, fromUser) {
      if (!labels[filter]) filter = 'all';
      buttons.forEach(function (b) { b.setAttribute('aria-pressed', String(b.getAttribute('data-filter') === filter)); });
      grid.classList.remove('is-filtering');
      void grid.offsetWidth;
      visible = [];
      items.forEach(function (item) {
        var show = filter === 'all' || item.getAttribute('data-cat').split(' ').indexOf(filter) > -1;
        item.hidden = !show;
        if (show) visible.push(item);
      });
      if (!reduceMotion.matches) grid.classList.add('is-filtering');
      empty.hidden = visible.length > 0;
      if (status) status.textContent = 'Showing ' + visible.length + ' ' + (filter === 'all' ? 'photographs' : labels[filter] + ' photographs');
      if (fromUser && window.history && history.replaceState) {
        var url = new URL(window.location.href);
        if (filter === 'all') url.searchParams.delete('filter'); else url.searchParams.set('filter', filter === 'stay' ? 'staycations' : filter);
        history.replaceState(null, '', url);
      }
    }
    buttons.forEach(function (b) { b.addEventListener('click', function () { apply(b.getAttribute('data-filter'), true); }); });
    var initial = new URLSearchParams(window.location.search).get('filter') || 'all';
    apply(aliases[initial] || initial, false);

    // Lightbox
    var dialog = $('[data-lightbox]');
    if (!dialog || typeof dialog.showModal !== 'function') {
      // Fallback: open the full image in the same tab
      items.forEach(function (item) {
        var btn = $('button', item);
        btn.addEventListener('click', function () { window.location.href = btn.getAttribute('data-full'); });
      });
      return;
    }
    var img = $('[data-lb-img]', dialog);
    var labelEl = $('[data-lb-label]', dialog);
    var countEl = $('[data-lb-count]', dialog);
    var index = 0;
    var opener = null;

    function show(i) {
      if (!visible.length) return;
      index = (i + visible.length) % visible.length;
      var btn = $('button', visible[index]);
      var thumb = $('img', btn);
      img.classList.add('is-loading');
      img.onload = function () { img.classList.remove('is-loading'); };
      img.src = btn.getAttribute('data-full');
      img.width = +btn.getAttribute('data-w');
      img.height = +btn.getAttribute('data-h');
      img.alt = thumb ? thumb.alt : '';
      labelEl.textContent = btn.getAttribute('data-label');
      countEl.textContent = (index + 1) + ' / ' + visible.length;
      // Warm the neighbours
      [index + 1, index - 1].forEach(function (n) {
        var nb = visible[(n + visible.length) % visible.length];
        if (nb) { var pre = new Image(); pre.src = $('button', nb).getAttribute('data-full'); }
      });
    }
    function open(item) {
      opener = $('button', item);
      show(visible.indexOf(item));
      dialog.showModal();
      doc.body.classList.add('is-locked');
    }
    function close() { dialog.close(); }
    dialog.addEventListener('close', function () {
      doc.body.classList.remove('is-locked');
      img.removeAttribute('src');
      if (opener) opener.focus({ preventScroll: true });
    });
    items.forEach(function (item) {
      $('button', item).addEventListener('click', function () { open(item); });
    });
    $('[data-lb-prev]', dialog).addEventListener('click', function () { show(index - 1); });
    $('[data-lb-next]', dialog).addEventListener('click', function () { show(index + 1); });
    $('[data-lb-close]', dialog).addEventListener('click', close);
    dialog.addEventListener('keydown', function (e) {
      if (e.key === 'ArrowRight') { e.preventDefault(); show(index + 1); }
      if (e.key === 'ArrowLeft') { e.preventDefault(); show(index - 1); }
    });
    // Close when clicking the empty backdrop area of the stage
    dialog.addEventListener('click', function (e) {
      if (e.target === dialog || e.target.classList.contains('lightbox__stage')) close();
    });
    // Swipe
    var startX = null, startY = null;
    dialog.addEventListener('touchstart', function (e) { startX = e.touches[0].clientX; startY = e.touches[0].clientY; }, { passive: true });
    dialog.addEventListener('touchend', function (e) {
      if (startX === null) return;
      var dx = e.changedTouches[0].clientX - startX;
      var dy = e.changedTouches[0].clientY - startY;
      if (Math.abs(dx) > 50 && Math.abs(dx) > Math.abs(dy)) show(index + (dx < 0 ? 1 : -1));
      startX = null;
    });
  }

  /* ---------- Contact: pathways + preview form ---------- */
  function initContact() {
    var form = $('[data-preview-form]');
    if (!form) return;
    var select = $('[data-type-select]', form);
    var paths = $$('[data-pathways] [data-type]');
    var status = $('[data-form-status]');

    function setType(type) {
      if (!$('option[value="' + type + '"]', select)) return;
      select.value = type;
      paths.forEach(function (p) { p.setAttribute('aria-pressed', String(p.getAttribute('data-type') === type)); });
    }
    var q = new URLSearchParams(window.location.search).get('type');
    if (q) setType(q);
    select.addEventListener('change', function () { setType(select.value); });
    paths.forEach(function (p) {
      p.addEventListener('click', function () {
        setType(p.getAttribute('data-type'));
        var target = $('#inquiry');
        target.scrollIntoView({ behavior: reduceMotion.matches ? 'auto' : 'smooth', block: 'start' });
        setTimeout(function () { $('#f-name').focus({ preventScroll: true }); }, reduceMotion.matches ? 0 : 600);
      });
    });
    form.addEventListener('submit', function (e) {
      e.preventDefault();
      status.hidden = false;
      status.textContent = 'Thank you for trying the inquiry preview. This concept does not send or store messages. Once La Casa Bella confirms its official channels, this form will connect directly to the team.';
      status.focus && status.setAttribute('tabindex', '-1');
      status.focus({ preventScroll: false });
    });
  }

  /* ---------- Sticky mobile CTA ---------- */
  function initStickyCta() {
    var cta = $('[data-sticky-cta]');
    if (!cta) return;
    var footer = $('.site-footer');
    var ticking = false;
    function update() {
      ticking = false;
      var y = window.scrollY;
      var nearFooter = footer && footer.getBoundingClientRect().top < window.innerHeight - 40;
      cta.classList.toggle('is-visible', y > window.innerHeight * 0.7 && !nearFooter);
    }
    window.addEventListener('scroll', function () { if (!ticking) { ticking = true; requestAnimationFrame(update); } }, { passive: true });
    update();
  }

  function init() {
    initHeader();
    initMenu();
    initHero();
    initReveal();
    initParallax();
    initServices();
    initRails();
    initGallery();
    initContact();
    initStickyCta();
  }
  if (doc.readyState === 'loading') doc.addEventListener('DOMContentLoaded', init);
  else init();
})();
