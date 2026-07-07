// lalutir.com — site.js
// Shared across every page. Two jobs: mobile nav toggle, and the Seaglass
// signature motion (pointer/scroll driven glass shift — see CLAUDE.md).
(function () {
  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // ---- Mobile nav toggle ----
  var toggle = document.querySelector('.nav-toggle');
  var links = document.getElementById('nav-links');
  if (toggle && links) {
    toggle.addEventListener('click', function () {
      var isOpen = links.classList.toggle('is-open');
      toggle.setAttribute('aria-expanded', String(isOpen));
    });
    links.addEventListener('click', function (e) {
      if (e.target.tagName === 'A') {
        links.classList.remove('is-open');
        toggle.setAttribute('aria-expanded', 'false');
      }
    });
  }

  // ---- Signature motion: hero glow follows the pointer, subtly ----
  var hero = document.querySelector('.hero-panel');
  if (hero && !reduceMotion) {
    document.addEventListener('mousemove', function (e) {
      var x = (e.clientX / window.innerWidth - 0.5) * 2;
      var y = (e.clientY / window.innerHeight - 0.5) * 2;
      hero.style.setProperty('--mx', x.toFixed(2));
      hero.style.setProperty('--my', y.toFixed(2));
    });
  }

  // ---- Signature motion: showcase cards come into soft focus on scroll ----
  // Deliberately NOT applied to .entry (resume) — that page is for scanning,
  // not delight. Restraint is the point (see CLAUDE.md, "Signature element").
  var focusables = document.querySelectorAll('.work-card, .project');
  if ('IntersectionObserver' in window && focusables.length) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        entry.target.classList.toggle('is-focused', entry.isIntersecting);
      });
    }, { threshold: 0.35 });
    focusables.forEach(function (el) { io.observe(el); });
  } else {
    focusables.forEach(function (el) { el.classList.add('is-focused'); });
  }

  // ---- Footer year ----
  var yearEl = document.getElementById('year');
  if (yearEl) { yearEl.textContent = new Date().getFullYear(); }
})();
