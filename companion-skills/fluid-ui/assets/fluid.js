'use strict';
/* fluid-ui 质感层运行时。零依赖,挂全局 Fluid,放在业务脚本之前。规则见 SKILL.md。
   这里只有手感原语:滑块、错峰、数字滚动、主题、悬浮提示。
   字典、格式化、图表、表格属于目标页面自己的逻辑,不在这里。

   最少接线:Fluid.init({ root: container }); 主题需显式传 themeRoot 和 prefix。 */

const Fluid = (() => {
  const cfg = { root: document, themeRoot: null, prefix: 'fluid-ui', onResize: null };
  const $ = (s, r = cfg.root) => r.querySelector(s);
  const movers = [];

  const reduced = () => matchMedia('(prefers-reduced-motion: reduce)').matches;

  /** 颜色绑定。把 var() 交给浏览器解析,不要把变量读进 JS —— 读出来是
      未解析的字符串,写死之后切主题会留着旧色。 */
  const color = (n) => `var(--fluid-${String(n).replace(/^--(?:fluid-)?/, '')})`;

  /** 外部来源的文本只经过这里,永远 textContent,绝不拼 innerHTML。 */
  function el(tag, cls, text) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }

  // ---------- 数字 ----------

  /** 滚动到新值,ease-out cubic。上一个值记在 dataset.v 上,
      所以第二次渲染是从旧值滚到新值,不是从 0 重来。
      fmt 由页面自己给 —— 单位、千分位、语言都是页面的事。 */
  function countTo(node, to, fmt = (v) => String(Math.round(v)), ms = 620) {
    const from = Number(node.dataset.v || 0);
    node.dataset.v = String(to);
    if (reduced() || from === to) { node.textContent = fmt(to); return; }
    const t0 = performance.now();
    (function step(now) {
      const p = Math.min(1, (now - t0) / ms);
      const e = 1 - Math.pow(1 - p, 3);
      node.textContent = fmt(from + (to - from) * e);
      if (p < 1) requestAnimationFrame(step);
    })(t0);
  }

  /** 入场错峰的延时,自带封顶 —— 不封顶时最后一个元素要等好几秒,
      观感是卡顿不是错落。 */
  const stagger = (i, step = 34, cap = 500) => Math.min(cap, i * step) + 'ms';

  // ---------- 选中态的滑动 ----------

  /** DOM 契约:.fluid-seg > .fluid-seg-pill + button[data-v],选中的按钮带 .fluid-on。 */
  function initSeg(sel, onPick) {
    const seg = typeof sel === 'string' ? $(sel) : sel;
    if (!seg) return () => {};
    const pill = $('.fluid-seg-pill', seg);
    const btns = [...seg.querySelectorAll('button')];
    const pad = parseFloat(getComputedStyle(seg).paddingLeft) || 0;

    function move(silent) {
      const on = seg.querySelector('button.fluid-on');
      if (!on || !pill) return;
      if (silent) pill.classList.add('fluid-silent');   // 首帧和重新测量不带动画
      pill.style.width = on.offsetWidth + 'px';
      pill.style.transform = `translateX(${on.offsetLeft - pad}px)`;
      if (silent) requestAnimationFrame(() => pill.classList.remove('fluid-silent'));
    }

    btns.forEach((b) => b.addEventListener('click', () => {
      if (b.classList.contains('fluid-on')) return;
      btns.forEach((x) => x.classList.toggle('fluid-on', x === b));
      move(false);
      if (onPick) onPick(b.dataset.v);
    }));

    move(true);
    movers.push(move);
    return move;
  }

  /** 控件文案宽度变了就重量:resize、字体加载完成、任何改写按钮文字的操作。
      同步量一次拿到新宽度,再挂一帧兜底 —— 只挂帧的话,页面在后台标签页时
      那一帧不触发,滑块会停在旧位置。 */
  function remeasure() {
    movers.forEach((m) => m(true));
    requestAnimationFrame(() => movers.forEach((m) => m(true)));
  }

  // ---------- 主题 ----------

  const theme = {
    get: () => cfg.themeRoot ? localStorage.getItem(cfg.prefix + '.theme') || 'auto' : 'auto',
    set(v) {
      if (!cfg.themeRoot) throw new Error('Fluid theme requires an explicit themeRoot');
      if (!['auto', 'light', 'dark'].includes(v)) throw new Error('Invalid Fluid theme');
      cfg.themeRoot.setAttribute('data-fluid-theme', v);
      localStorage.setItem(cfg.prefix + '.theme', v);
    },
  };

  // ---------- 悬浮提示 ----------

  let tipEl = null;
  function tipNode() {
    if (!tipEl) {
      const host = cfg.root === document ? document.body : cfg.root;
      tipEl = host.appendChild(el('div', 'fluid-tip'));
      tipEl.setAttribute('role', 'status');
      tipEl.setAttribute('aria-live', 'polite');
    }
    return tipEl;
  }
  function showTip(ev, build) {
    const n = tipNode();
    n.textContent = '';
    build(n);
    n.classList.add('fluid-on');
    const r = n.getBoundingClientRect();
    let x = ev.clientX + 14;
    let y = ev.clientY - r.height - 12;
    if (x + r.width > innerWidth - 8) x = ev.clientX - r.width - 14;
    if (y < 8) y = ev.clientY + 18;
    n.style.left = x + 'px';
    n.style.top = y + 'px';
  }
  const hideTip = () => tipEl && tipEl.classList.remove('fluid-on');

  /** hover 与键盘 focus 给同样的信息。节点记得给 tabindex。 */
  function bindTip(node, build) {
    node.addEventListener('pointermove', (e) => showTip(e, build));
    node.addEventListener('pointerleave', hideTip);
    node.addEventListener('focus', () => {
      const r = node.getBoundingClientRect();
      showTip({ clientX: r.left + r.width / 2, clientY: r.top }, build);
    });
    node.addEventListener('blur', hideTip);
  }

  // ---------- 接线 ----------

  function init(opts = {}) {
    Object.assign(cfg, opts);
    if (cfg.themeRoot) theme.set(theme.get());

    // 仅在显式启用主题时接入作用域内的主题控件。
    const ts = cfg.themeRoot && $('[data-fluid-theme-control]');
    if (ts) {
      const now = theme.get();
      ts.querySelectorAll('button').forEach((b) => b.classList.toggle('fluid-on', b.dataset.v === now));
      initSeg(ts, (v) => theme.set(v));   // 颜色绑了 var(),切主题不用重画
    }

    let rt;
    addEventListener('resize', () => {
      remeasure();
      if (cfg.onResize) { clearTimeout(rt); rt = setTimeout(cfg.onResize, 180); }
    });

    if (document.fonts && document.fonts.ready) document.fonts.ready.then(remeasure);
  }

  return { $, el, color, reduced, countTo, stagger, initSeg, remeasure, bindTip, hideTip, theme, init };
})();
