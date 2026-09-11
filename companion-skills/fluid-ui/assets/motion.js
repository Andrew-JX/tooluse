/* fluid-ui 运动层运行时。零依赖,挂全局 Fluid,放在业务脚本之前。规则见 SKILL.md。
   这里只有手感原语:滑块位移、入场错峰、数字滚动。
   选中状态、视图显示、浮层提示、配色和格式化属于目标页面自己的逻辑,不在这里。

   挂在 globalThis 上,所以 <script> 与 type="module" 两种加载方式都取得到。
   最少接线:const ui = Fluid.create(container);
             const move = ui.indicator('.fluid-track');   // 业务改完状态后调 move()
   组件卸载或路由切换时 ui.destroy()。主题见 ../references/theme.md。 */

globalThis.Fluid = (() => {
  const reduced = () => matchMedia("(prefers-reduced-motion: reduce)").matches;

  /** 入场错峰的延时,自带封顶 —— 不封顶时最后一个元素要等好几秒,
      观感是卡顿不是错落。 */
  const stagger = (i, step = 34, cap = 500) => Math.min(cap, i * step) + "ms";

  // ---------- 数字 ----------

  /** 每个节点一份动画状态。新目标先作废旧的 RAF,再从屏幕上当前的值继续 ——
      否则两个循环会同时写一个节点,而且起点会取成上一次的目标值而不是可见值。
      fmt 由页面自己给:单位、千分位、语言都是页面的事。 */
  const counters = new WeakMap();

  function countTo(node, to, fmt = (v) => String(Math.round(v)), ms = 620) {
    const prev = counters.get(node);
    if (prev && prev.raf) cancelAnimationFrame(prev.raf);
    const from = prev ? prev.value : Number(node.dataset.v || 0);
    node.dataset.v = String(to);
    if (reduced() || from === to) {
      counters.set(node, { value: to, raf: 0 });
      node.textContent = fmt(to);
      return;
    }
    const t0 = performance.now();
    const state = { value: from, raf: 0 };
    counters.set(node, state);
    const step = (now) => {
      const p = Math.min(1, (now - t0) / ms);
      state.value = from + (to - from) * (1 - (1 - p) ** 3);
      node.textContent = fmt(state.value);
      state.raf = p < 1 ? requestAnimationFrame(step) : 0;
    };
    state.raf = requestAnimationFrame(step);
  }

  // ---------- 选中态的滑动 ----------

  /** 只搬滑块,不碰选中状态:业务先决定谁选中(改 DOM 或直接把目标元素传进来),
      再调 move()。这样请求失败或外部改状态时,视觉不会和真状态分叉。
      测量用 rect 差值而不是 offsetLeft 减 paddingLeft —— 轨道的 padding、border、
      box-sizing 和排布方式都由页面自己定,换掉也不会静默错位。
      纵向位置和高度不写,由页面的 CSS 决定。 */
  function makeMover(track, sel) {
    const pill =
      track.querySelector(":scope > .fluid-indicator") ||
      track.querySelector(".fluid-indicator");
    let last = null;
    return function move(target, opts = {}) {
      const on =
        target instanceof Element ? target : track.querySelector(sel) || last;
      if (!on || !pill) return;
      last = on;
      const base = pill.offsetParent || track;
      const br = base.getBoundingClientRect();
      const r = on.getBoundingClientRect();
      if (opts.silent) pill.classList.add("fluid-silent"); // 首帧和重新测量不带动画
      pill.style.width = r.width + "px";
      pill.style.transform = `translateX(${r.left - br.left - base.clientLeft}px)`;
      if (opts.silent)
        requestAnimationFrame(() => pill.classList.remove("fluid-silent"));
    };
  }

  // ---------- 作用域 ----------

  /** 一个容器一个作用域,自带销毁。全局单例会在第二次初始化时覆盖第一个作用域的配置,
      监听和已注册的滑块也摘不掉,SPA 重挂或弹层里的第二个容器都会出问题。 */
  function create(root = document) {
    const movers = new Set();
    let disposed = false;

    /** 控件文案宽度变了就重量:resize、字体加载完成、任何改写选项文字的操作。
        同步量一次拿到新宽度,再挂一帧兜底 —— 只挂帧的话,页面在后台标签页时
        那一帧不触发,滑块会停在旧位置。 */
    function remeasure() {
      if (disposed) return;
      movers.forEach((m) => m(null, { silent: true }));
      requestAnimationFrame(() => {
        if (!disposed) movers.forEach((m) => m(null, { silent: true }));
      });
    }

    const onResize = () => remeasure();
    addEventListener("resize", onResize);
    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(() => remeasure());
    }

    return {
      root,
      reduced,
      stagger,
      countTo,
      remeasure,
      /** 注册一个滑块:返回 move(target?, { silent }),并纳入 resize 与字体加载后的重量。
          DOM 契约:轨道带 .fluid-track,内部一个 .fluid-indicator,选项默认取 sel。 */
      indicator(target, sel = ".fluid-on") {
        const track =
          typeof target === "string" ? root.querySelector(target) : target;
        if (!track) return () => {};
        const move = makeMover(track, sel);
        movers.add(move);
        move(null, { silent: true });
        return move;
      },
      /** 单个滑块随组件卸载时摘掉,不必销毁整个作用域。 */
      drop(move) {
        movers.delete(move);
      },
      destroy() {
        disposed = true;
        removeEventListener("resize", onResize);
        movers.clear();
      },
    };
  }

  return { create, countTo, stagger, reduced };
})();
