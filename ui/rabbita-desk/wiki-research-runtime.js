// Interactive 6-Stage Research Structure & Visualization Workbench for MoonDesk.
// Each stage provides a purpose-built interactive SVG visualization tool
// grounded in core research rigor: tension, scope, causal mechanism & rivals,
// non-tautological measurement, falsification, and bounded contribution.

const STORAGE_KEY = 'moondesk.research_structure.v1'

const DEFAULT_OPC_DATA = {
  title: 'OPC的发展及其成功因素：组织结构、扩张机制与评估方法',
  puzzle: '相同AI工具条件下，为何部分一人公司（OPC）实现高杠杆扩张，而另一些在增加智能体密度D后净绩效反而坍塌？',
  activeStage: 1,
  densityD: 12,
  regimeQ: 1.6,
  selectedRing: 'core',
  selectedRq: 'RQ2',
  showRivals: true,
  selectedNode: 'Q',
  selectedHypothesis: 'H1',
  selectedSource: 'telemetry',
  selectedRegime: 'leverage',
}

function readState(workspaceId) {
  try {
    const all = JSON.parse(globalThis.localStorage?.getItem(STORAGE_KEY) || '{}')
    return { ...DEFAULT_OPC_DATA, ...(all[workspaceId] || {}) }
  } catch {
    return { ...DEFAULT_OPC_DATA }
  }
}

function writeState(workspaceId, patch) {
  try {
    const all = JSON.parse(globalThis.localStorage?.getItem(STORAGE_KEY) || '{}')
    const next = { ...DEFAULT_OPC_DATA, ...(all[workspaceId] || {}), ...patch }
    all[workspaceId] = next
    globalThis.localStorage?.setItem(STORAGE_KEY, JSON.stringify(all))
    return next
  } catch {
    return { ...DEFAULT_OPC_DATA, ...patch }
  }
}

function el(tag, className, text = '') {
  const node = document.createElement(tag)
  if (className) node.className = className
  if (text) node.textContent = text
  return node
}

function renderStage1Tension(state, rerender) {
  const wrap = el('div', 'research-stage-viz')
  const D = Number(state.densityD) || 12
  const Q = Number(state.regimeQ) || 1.6
  const alpha = 0.55
  const beta = 0.12
  const gamma = 1.5

  const calcLinear = d => d * Q - alpha * d - gamma
  const calcNet = d => d * Q - alpha * d - (beta * d * d) / Q - gamma

  const w = 520
  const h = 230
  const padL = 48
  const padR = 20
  const padT = 22
  const padB = 34
  const plotW = w - padL - padR
  const plotH = h - padT - padB
  const xFor = d => padL + (d / 20) * plotW
  const yMin = -25
  const yMax = 45
  const yFor = val => padT + ((yMax - Math.max(yMin, Math.min(yMax, val))) / (yMax - yMin)) * plotH

  const linearPts = []
  const netPts = []
  for (let d = 0; d <= 20; d += 1) {
    linearPts.push(`${xFor(d).toFixed(1)},${yFor(calcLinear(d)).toFixed(1)}`)
    netPts.push(`${xFor(d).toFixed(1)},${yFor(calcNet(d)).toFixed(1)}`)
  }
  const zeroY = yFor(0).toFixed(1)
  const curX = xFor(D).toFixed(1)
  const curLinY = yFor(calcLinear(D)).toFixed(1)
  const curNetY = yFor(calcNet(D)).toFixed(1)
  const gap = (calcLinear(D) - calcNet(D)).toFixed(1)
  const netVal = calcNet(D).toFixed(1)

  wrap.innerHTML = `
    <div style="display:flex;justify-content:space-between;align-items:center;gap:8px;margin-bottom:8px;flex-wrap:wrap;">
      <strong style="font-size:13px;color:#252925;">Stage 1 · 期望与现实的张力图 (Expectation vs. Reality)</strong>
      <span style="font-size:11px;color:#365A50;background:#E4E6DD;padding:2px 8px;border-radius:99px;">协调成本差距 Δ = ${gap}</span>
    </div>
    <svg viewBox="0 0 ${w} ${h}" style="width:100%;height:auto;background:#FCFBF8;border:1px solid #E4E6DD;border-radius:8px;">
      <line x1="${padL}" y1="${zeroY}" x2="${w - padR}" y2="${zeroY}" stroke="#C8C5BB" stroke-dasharray="4 3" />
      <line x1="${padL}" y1="${padT}" x2="${padL}" y2="${h - padB}" stroke="#9BA4B5" />
      <line x1="${padL}" y1="${h - padB}" x2="${w - padR}" y2="${h - padB}" stroke="#9BA4B5" />
      <polyline fill="none" stroke="#9BA4B5" stroke-width="2" stroke-dasharray="5 4" points="${linearPts.join(' ')}" />
      <polyline fill="none" stroke="#365A50" stroke-width="2.5" points="${netPts.join(' ')}" />
      <line x1="${curX}" y1="${curLinY}" x2="${curX}" y2="${curNetY}" stroke="#B84A39" stroke-width="2" />
      <circle cx="${curX}" cy="${curLinY}" r="4" fill="#9BA4B5" />
      <circle cx="${curX}" cy="${curNetY}" r="5" fill="#B84A39" />
      <text x="${padL + 6}" y="${padT + 12}" font-size="10" fill="#64748B">-- 期望线性产出 (DQ − αD − γ)</text>
      <text x="${padL + 6}" y="${padT + 26}" font-size="10" fill="#365A50" font-weight="600">― 实际净绩效 P = DQ − αD − βD²/Q − γ</text>
      <text x="${Number(curX) + 6}" y="${(Number(curLinY) + Number(curNetY)) / 2}" font-size="10" fill="#B84A39" font-weight="600">Δ=${gap}</text>
      <text x="${w / 2}" y="${h - 8}" text-anchor="middle" font-size="10" fill="#555">智能体密度 D = ${D}（当前 P = ${netVal}）</text>
    </svg>
    <div style="display:flex;gap:12px;align-items:center;margin-top:8px;flex-wrap:wrap;font-size:12px;">
      <label style="display:flex;align-items:center;gap:6px;">密度 D: <input type="range" min="1" max="20" step="1" value="${D}" data-research-d /></label>
      <div style="display:flex;gap:4px;">
        ${[0.8, 1.6, 3.2].map(q => `<button type="button" class="secondary-button" data-research-q="${q}" style="${Q === q ? 'background:#365A50;color:#fff;border-color:#365A50;' : ''}">Q=${q}</button>`).join('')}
      </div>
    </div>
    <p style="margin:8px 0 0;font-size:12px;color:#475569;line-height:1.5;"><strong>核心研究张力：</strong>${state.puzzle}</p>
  `
  wrap.querySelector('[data-research-d]')?.addEventListener('input', e => {
    rerender({ densityD: Number(e.target.value) })
  })
  for (const btn of wrap.querySelectorAll('[data-research-q]')) {
    btn.addEventListener('click', () => rerender({ regimeQ: Number(btn.getAttribute('data-research-q')) }))
  }
  return wrap
}

function renderStage2Scope(state, rerender) {
  const wrap = el('div', 'research-stage-viz')
  const rings = {
    core: { title: '核心研究对象：组织形态 OPC', detail: '单一最终问责人 + 持续嵌入智能体 + 跨任务M/L/F资产 + 可核验交付（核心实证与案例样本）' },
    context: { title: '对照与背景：统计口径 / 数字化自雇', detail: '政策登记群体与无资产积累的自由职业者；用于政策对照与对照组比较' },
    outer: { title: '研究边界之外：纯法律登记一人公司 / 传统科层', detail: '仅具备法人资格而无AI智能体编排的传统个体户，或传统多层级科层组织' },
  }
  const rqs = {
    RQ1: 'RQ1 组织条件识别 → 问卷(600–800) + 筛选 + 案例 → 分类规则与概念词典',
    RQ2: 'RQ2 组织机制解释 → 30+ OPC × 26周遥测 + 访谈 → Q调节D与门槛θ检验',
    RQ3: 'RQ3 评估工具构建 → 预测试 + 双评分 + 纵向结果 → OPC-MM 与 OPEM 手册',
  }
  const activeRing = rings[state.selectedRing] || rings.core
  const activeRq = rqs[state.selectedRq] || rqs.RQ2

  wrap.innerHTML = `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">
      <strong style="font-size:13px;color:#252925;">Stage 2 · 概念边界与分析单位靶心图 (Scope & Unit Bullseye)</strong>
    </div>
    <svg viewBox="0 0 520 220" style="width:100%;height:auto;background:#FCFBF8;border:1px solid #E4E6DD;border-radius:8px;">
      <ellipse cx="170" cy="110" rx="150" ry="92" fill="${state.selectedRing === 'outer' ? '#E2E8F0' : '#F4F0E7'}" stroke="#9BA4B5" stroke-width="1.5" style="cursor:pointer" data-ring="outer" />
      <ellipse cx="170" cy="110" rx="108" ry="66" fill="${state.selectedRing === 'context' ? '#DCE8E2' : '#FFFFFF'}" stroke="#6B8E82" stroke-width="1.5" style="cursor:pointer" data-ring="context" />
      <ellipse cx="170" cy="110" rx="64" ry="40" fill="${state.selectedRing === 'core' ? '#365A50' : '#4A7367'}" stroke="#252925" stroke-width="1.5" style="cursor:pointer" data-ring="core" />
      <text x="170" y="106" text-anchor="middle" font-size="11" fill="#fff" font-weight="600" style="pointer-events:none">组织形态 OPC</text>
      <text x="170" y="122" text-anchor="middle" font-size="9" fill="#E4E6DD" style="pointer-events:none">(核心样本)</text>
      <text x="170" y="56" text-anchor="middle" font-size="9.5" fill="#365A50" style="pointer-events:none">数字化自雇 / 政策口径</text>
      <text x="170" y="29" text-anchor="middle" font-size="9" fill="#64748B" style="pointer-events:none">纯法律登记 / 传统科层 (Out of Scope)</text>
      <text x="345" y="40" font-size="11" fill="#252925" font-weight="600">分析单位与研究问题</text>
      ${['RQ1', 'RQ2', 'RQ3'].map((id, i) => `
        <g style="cursor:pointer" data-rq="${id}">
          <rect x="345" y="${54 + i * 48}" width="155" height="38" rx="6" fill="${state.selectedRq === id ? '#365A50' : '#fff'}" stroke="#C8C5BB" />
          <text x="357" y="${77 + i * 48}" font-size="11" fill="${state.selectedRq === id ? '#fff' : '#252925'}" font-weight="600">${id} · ${id === 'RQ1' ? '组织条件' : id === 'RQ2' ? '扩张机制' : '评估体系'}</text>
        </g>
      `).join('')}
    </svg>
    <div style="margin-top:8px;padding:8px 10px;background:#F4F0E7;border-radius:6px;font-size:12px;line-height:1.5;">
      <div><strong>${activeRing.title}：</strong>${activeRing.detail}</div>
      <div style="margin-top:4px;color:#365A50;"><strong>${activeRq}</strong></div>
    </div>
  `
  for (const r of wrap.querySelectorAll('[data-ring]')) {
    r.addEventListener('click', () => rerender({ selectedRing: r.getAttribute('data-ring') }))
  }
  for (const rq of wrap.querySelectorAll('[data-rq]')) {
    rq.addEventListener('click', () => rerender({ selectedRq: rq.getAttribute('data-rq') }))
  }
  return wrap
}

function renderStage3Mechanism(state, rerender) {
  const wrap = el('div', 'research-stage-viz')
  const nodeInfo = {
    MLF: '三类杠杆资产 (M 记忆 / L 学习 / F 结构)：只有进入后续任务执行，存量才转化为协调能力。',
    Q: '核心中介构念 Q (协调质量)：决定任务分解、记忆检索、权限边界与验收一致性的匹配度。',
    D: '操作变量 D (智能体密度)：并行工作进程与智能体数量；本身不自动产生净绩效。',
    P: '净绩效与外部结果 (P & OPEM)：当 Q > θ 时 D 转化为杠杆；当 Q < θ 时协调成本 βD²/Q 导致坍塌。',
    Rivals: '竞争性解释控制：1) 创始人经验/能力（问卷+固定效应）；2) 模型能力跃迁（时间固定效应）；3) 任务耦合度（H4交互项）；4) 幸存者/选择偏差（纵向+负例）。',
  }
  const showRivals = state.showRivals !== false
  wrap.innerHTML = `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;gap:8px;flex-wrap:wrap;">
      <strong style="font-size:13px;color:#252925;">Stage 3 · 因果机制与竞争性解释DAG (Causal Mechanism & Rivals)</strong>
      <button type="button" class="secondary-button" data-toggle-rivals>${showRivals ? '隐藏竞争性解释' : '显示竞争性解释'}</button>
    </div>
    <svg viewBox="0 0 520 225" style="width:100%;height:auto;background:#FCFBF8;border:1px solid #E4E6DD;border-radius:8px;">
      <defs>
        <marker id="rs_arr" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M 0 1 L 10 5 L 0 9 z" fill="#365A50"/></marker>
        <marker id="rs_arr_r" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M 0 1 L 10 5 L 0 9 z" fill="#B84A39"/></marker>
      </defs>
      <g style="cursor:pointer" data-node="MLF">
        <rect x="18" y="24" width="126" height="48" rx="6" fill="${state.selectedNode === 'MLF' ? '#365A50' : '#E4E6DD'}" stroke="#365A50"/>
        <text x="81" y="45" text-anchor="middle" font-size="11" font-weight="600" fill="${state.selectedNode === 'MLF' ? '#fff' : '#252925'}">资产存量 M / L / F</text>
        <text x="81" y="61" text-anchor="middle" font-size="9" fill="${state.selectedNode === 'MLF' ? '#E4E6DD' : '#555'}">记忆 · 学习 · 结构</text>
      </g>
      <g style="cursor:pointer" data-node="Q">
        <rect x="195" y="24" width="130" height="48" rx="6" fill="${state.selectedNode === 'Q' ? '#2F5597' : '#EEF2F7'}" stroke="#2F5597"/>
        <text x="260" y="45" text-anchor="middle" font-size="11" font-weight="600" fill="${state.selectedNode === 'Q' ? '#fff' : '#252925'}">协调质量 Q</text>
        <text x="260" y="61" text-anchor="middle" font-size="9" fill="${state.selectedNode === 'Q' ? '#E2E8F0' : '#555'}">门槛判定: Q &gt; θ ?</text>
      </g>
      <g style="cursor:pointer" data-node="D">
        <rect x="18" y="128" width="126" height="46" rx="6" fill="${state.selectedNode === 'D' ? '#365A50' : '#FFF'}" stroke="#D97706"/>
        <text x="81" y="149" text-anchor="middle" font-size="11" font-weight="600" fill="${state.selectedNode === 'D' ? '#fff' : '#252925'}">智能体密度 D</text>
        <text x="81" y="164" text-anchor="middle" font-size="9" fill="${state.selectedNode === 'D' ? '#E4E6DD' : '#666'}">并行规模扩张</text>
      </g>
      <g style="cursor:pointer" data-node="P">
        <rect x="372" y="76" width="130" height="54" rx="6" fill="${state.selectedNode === 'P' ? '#365A50' : '#FFF'}" stroke="#365A50"/>
        <text x="437" y="99" text-anchor="middle" font-size="11" font-weight="600" fill="${state.selectedNode === 'P' ? '#fff' : '#252925'}">净绩效 P &amp; OPEM</text>
        <text x="437" y="116" text-anchor="middle" font-size="9" fill="${state.selectedNode === 'P' ? '#E4E6DD' : '#555'}">生存 · 成长 · 壁垒 · 韧性</text>
      </g>
      <line x1="144" y1="48" x2="193" y2="48" stroke="#365A50" stroke-width="2" marker-end="url(#rs_arr)"/>
      <line x1="325" y1="54" x2="370" y2="92" stroke="#365A50" stroke-width="2" marker-end="url(#rs_arr)"/>
      <line x1="144" y1="150" x2="370" y2="112" stroke="#365A50" stroke-width="2" marker-end="url(#rs_arr)"/>
      <line x1="260" y1="72" x2="260" y2="128" stroke="#2F5597" stroke-width="1.5" stroke-dasharray="4 3"/>
      <text x="266" y="106" font-size="9.5" fill="#2F5597" font-weight="600">调节 D→P</text>
      ${showRivals ? `
        <g style="cursor:pointer" data-node="Rivals">
          <rect x="195" y="162" width="142" height="44" rx="6" fill="#FEF2F2" stroke="#B84A39" stroke-dasharray="4 3"/>
          <text x="266" y="180" text-anchor="middle" font-size="10" font-weight="600" fill="#B84A39">竞争性解释 (Rivals)</text>
          <text x="266" y="196" text-anchor="middle" font-size="8.5" fill="#7F1D1D">创始人能力 · 模型跃迁 · 任务耦合</text>
          <line x1="337" y1="176" x2="412" y2="132" stroke="#B84A39" stroke-width="1.5" stroke-dasharray="4 3" marker-end="url(#rs_arr_r)"/>
        </g>
      ` : ''}
    </svg>
    <p style="margin:8px 0 0;font-size:12px;color:#252925;background:#F4F0E7;padding:8px 10px;border-radius:6px;line-height:1.5;">${nodeInfo[state.selectedNode] || nodeInfo.Q}</p>
  `
  wrap.querySelector('[data-toggle-rivals]')?.addEventListener('click', () => rerender({ showRivals: !showRivals }))
  for (const n of wrap.querySelectorAll('[data-node]')) {
    n.addEventListener('click', () => rerender({ selectedNode: n.getAttribute('data-node') }))
  }
  return wrap
}

function renderStage4Measurement(state, rerender) {
  const wrap = el('div', 'research-stage-viz')
  const details = {
    telemetry: '系统遥测 (APD, MCI, ELR)：客观记录智能体密度、记忆检索与错误修正时序，不直接读取财务结果。',
    survey: '组织问卷 + 双人独立评分 (OPC-MM)：测量结构资产 FE 与自举能力 BS，与结果采集分离。',
    business: '独立经营记录 (OPEM：生存/成长/壁垒/韧性)：滞后 3–6 个月从独立账务/客户记录获取，杜绝同源偏差与循环论证。',
  }
  wrap.innerHTML = `
    <div style="margin-bottom:8px;"><strong style="font-size:13px;color:#252925;">Stage 4 · 非同源独立测量映射 (Non-Tautology Source Separation)</strong></div>
    <svg viewBox="0 0 520 205" style="width:100%;height:auto;background:#FCFBF8;border:1px solid #E4E6DD;border-radius:8px;">
      <text x="85" y="20" text-anchor="middle" font-size="10.5" font-weight="600" fill="#365A50">自变量 / 中介 (OPC-MM)</text>
      <text x="260" y="20" text-anchor="middle" font-size="10.5" font-weight="600" fill="#252925">独立数据源隔离</text>
      <text x="435" y="20" text-anchor="middle" font-size="10.5" font-weight="600" fill="#2F5597">因变量 (OPEM)</text>

      <rect x="20" y="34" width="130" height="62" rx="6" fill="#E4E6DD" stroke="#365A50" style="cursor:pointer" data-src="telemetry"/>
      <text x="85" y="57" text-anchor="middle" font-size="10.5" font-weight="600" fill="#252925" style="pointer-events:none">APD · MCI · ELR</text>
      <text x="85" y="75" text-anchor="middle" font-size="9" fill="#555" style="pointer-events:none">内部密度与学习遥测</text>

      <rect x="20" y="112" width="130" height="62" rx="6" fill="#E4E6DD" stroke="#365A50" style="cursor:pointer" data-src="survey"/>
      <text x="85" y="135" text-anchor="middle" font-size="10.5" font-weight="600" fill="#252925" style="pointer-events:none">FE · BS</text>
      <text x="85" y="153" text-anchor="middle" font-size="9" fill="#555" style="pointer-events:none">结构工程与自举能力</text>

      <rect x="195" y="38" width="130" height="38" rx="6" fill="${state.selectedSource === 'telemetry' ? '#365A50' : '#fff'}" stroke="#C8C5BB" style="cursor:pointer" data-src="telemetry"/>
      <text x="260" y="61" text-anchor="middle" font-size="10" fill="${state.selectedSource === 'telemetry' ? '#fff' : '#252925'}" style="pointer-events:none">MoonClaw/Book 遥测</text>

      <rect x="195" y="88" width="130" height="38" rx="6" fill="${state.selectedSource === 'survey' ? '#365A50' : '#fff'}" stroke="#C8C5BB" style="cursor:pointer" data-src="survey"/>
      <text x="260" y="111" text-anchor="middle" font-size="10" fill="${state.selectedSource === 'survey' ? '#fff' : '#252925'}" style="pointer-events:none">组织问卷 &amp; 双评分</text>

      <rect x="195" y="140" width="130" height="40" rx="6" fill="${state.selectedSource === 'business' ? '#2F5597' : '#EEF2F7'}" stroke="#2F5597" style="cursor:pointer" data-src="business"/>
      <text x="260" y="164" text-anchor="middle" font-size="10" fill="${state.selectedSource === 'business' ? '#fff' : '#2F5597'}" style="pointer-events:none">独立经营账务 (+3~6月)</text>

      <rect x="370" y="66" width="130" height="90" rx="6" fill="#EEF2F7" stroke="#2F5597" style="cursor:pointer" data-src="business"/>
      <text x="435" y="96" text-anchor="middle" font-size="10.5" font-weight="600" fill="#252925" style="pointer-events:none">生存 · 成长</text>
      <text x="435" y="114" text-anchor="middle" font-size="10.5" font-weight="600" fill="#252925" style="pointer-events:none">壁垒 · 韧性</text>
      <text x="435" y="136" text-anchor="middle" font-size="9" fill="#2F5597" style="pointer-events:none">零同源共享偏差</text>

      <line x1="150" y1="60" x2="195" y2="57" stroke="#365A50" stroke-width="1.8"/>
      <line x1="150" y1="140" x2="195" y2="107" stroke="#365A50" stroke-width="1.8"/>
      <line x1="325" y1="160" x2="370" y2="120" stroke="#2F5597" stroke-width="1.8"/>
      <line x1="182" y1="30" x2="182" y2="190" stroke="#B84A39" stroke-dasharray="3 3" opacity="0.45"/>
      <line x1="338" y1="30" x2="338" y2="190" stroke="#B84A39" stroke-dasharray="3 3" opacity="0.45"/>
    </svg>
    <p style="margin:8px 0 0;font-size:12px;color:#252925;background:#F4F0E7;padding:8px 10px;border-radius:6px;line-height:1.5;">${details[state.selectedSource] || details.telemetry}</p>
  `
  for (const s of wrap.querySelectorAll('[data-src]')) {
    s.addEventListener('click', () => rerender({ selectedSource: s.getAttribute('data-src') }))
  }
  return wrap
}

function renderStage5Falsification(state, rerender) {
  const wrap = el('div', 'research-stage-viz')
  const hyps = [
    { id: 'H1', label: 'H1a/b 门槛调节', pred: 'Q 调节 D→P，存在异质性门槛 θ', falsify: '若高 Q 与低 Q 组斜率无显著差异，或门槛 θ 不存在，则证伪。', test: 'Hansen 门槛回归 + 置信区间' },
    { id: 'H2', label: 'H2a/b 记忆连续性', pred: 'MCI 改善后续交付、留存与韧性', falsify: '若控制历史绩效后 MCI 滞后项系数为 0 或反向因果主导，则证伪。', test: '滞后效应 + 反向因果检验' },
    { id: 'H3', label: 'H3a/b 错误学习', pred: 'ELR 降低重复错误与恢复时间', falsify: '若规则启用后同类错误率未下降，则证伪。', test: '事件序列与纵向面板' },
    { id: 'H4', label: 'H4 任务耦合边界', pred: '高任务耦合抬高所需协调门槛 θ', falsify: '若高耦合任务与低耦合任务门槛 θ 无差异，则证伪。', test: '三向交互 + 分行业门槛' },
    { id: 'H5', label: 'H5 政策中介效应', pred: '政策资源经由 M/L/F 影响外部绩效', falsify: '若政策直接影响绩效且与 M/L/F 无关，则中介机制证伪。', test: '政策时序比较 + 中介检验' },
  ]
  const cur = hyps.find(h => h.id === state.selectedHypothesis) || hyps[0]
  wrap.innerHTML = `
    <div style="margin-bottom:8px;"><strong style="font-size:13px;color:#252925;">Stage 5 · 可证伪性与稳健性压力测试 (Falsification & Stress-Test)</strong></div>
    <div style="display:flex;gap:4px;flex-wrap:wrap;margin-bottom:10px;">
      ${hyps.map(h => `<button type="button" class="secondary-button" data-hyp="${h.id}" style="${cur.id === h.id ? 'background:#365A50;color:#fff;border-color:#365A50;' : ''}">${h.label}</button>`).join('')}
    </div>
    <div style="border:1px solid #C8C5BB;border-radius:8px;overflow:hidden;font-size:12px;">
      <div style="background:#365A50;color:#fff;padding:8px 10px;font-weight:600;">${cur.label}</div>
      <div style="padding:10px;background:#fff;border-bottom:1px solid #E4E6DD;"><strong>预测信号：</strong>${cur.pred}</div>
      <div style="padding:10px;background:#FEF2F2;border-bottom:1px solid #E4E6DD;color:#7F1D1D;"><strong>证伪条件（什么结果会推翻它）：</strong>${cur.falsify}</div>
      <div style="padding:10px;background:#F4F0E7;"><strong>稳健性与识别检验：</strong>${cur.test}</div>
    </div>
  `
  for (const b of wrap.querySelectorAll('[data-hyp]')) {
    b.addEventListener('click', () => rerender({ selectedHypothesis: b.getAttribute('data-hyp') }))
  }
  return wrap
}

function renderStage6Contribution(state, rerender) {
  const wrap = el('div', 'research-stage-viz')
  const regimes = {
    leverage: '高杠杆区 (High Q, Modular)：资产支撑密度扩张，智能体编排产生超线性净产出。',
    fragile: '高门槛高压区 (High Q, Coupled)：需先强化接口规约 F 与验收规则，再逐步提高 D。',
    collapse: '失控坍塌区 (Low Q, High Coupling)：盲目增加智能体导致返工与协调成本 βD²/Q 失控。',
    tool: '工具依赖期 (Low Q, Modular)：尚处于个人使用工具阶段，需优先沉淀 M/L/F 资产。',
  }
  wrap.innerHTML = `
    <div style="margin-bottom:8px;"><strong style="font-size:13px;color:#252925;">Stage 6 · 适用边界与三层贡献图 (Bounded Contribution & Regime Map)</strong></div>
    <svg viewBox="0 0 520 205" style="width:100%;height:auto;background:#FCFBF8;border:1px solid #E4E6DD;border-radius:8px;">
      <text x="150" y="16" text-anchor="middle" font-size="10" font-weight="600" fill="#252925">任务耦合度：低 (模块化)</text>
      <text x="370" y="16" text-anchor="middle" font-size="10" font-weight="600" fill="#252925">任务耦合度：高 (强依赖)</text>
      <rect x="45" y="24" width="215" height="82" rx="6" fill="${state.selectedRegime === 'leverage' ? '#365A50' : '#E4E6DD'}" stroke="#365A50" style="cursor:pointer" data-reg="leverage"/>
      <text x="152" y="58" text-anchor="middle" font-size="11" font-weight="600" fill="${state.selectedRegime === 'leverage' ? '#fff' : '#252925'}" style="pointer-events:none">分形杠杆扩张区 (Q &gt; θ)</text>
      <text x="152" y="76" text-anchor="middle" font-size="9.5" fill="${state.selectedRegime === 'leverage' ? '#E4E6DD' : '#555'}" style="pointer-events:none">TOL 结论核心适用边界</text>

      <rect x="270" y="24" width="215" height="82" rx="6" fill="${state.selectedRegime === 'fragile' ? '#2F5597' : '#EEF2F7'}" stroke="#2F5597" style="cursor:pointer" data-reg="fragile"/>
      <text x="377" y="58" text-anchor="middle" font-size="11" font-weight="600" fill="${state.selectedRegime === 'fragile' ? '#fff' : '#252925'}" style="pointer-events:none">高门槛受限区 (θ 抬高)</text>
      <text x="377" y="76" text-anchor="middle" font-size="9.5" fill="${state.selectedRegime === 'fragile' ? '#E2E8F0' : '#555'}" style="pointer-events:none">先复用与外部协作，慎扩 D</text>

      <rect x="45" y="114" width="215" height="80" rx="6" fill="${state.selectedRegime === 'tool' ? '#64748B' : '#F4F0E7'}" stroke="#9BA4B5" style="cursor:pointer" data-reg="tool"/>
      <text x="152" y="148" text-anchor="middle" font-size="11" font-weight="600" fill="${state.selectedRegime === 'tool' ? '#fff' : '#252925'}" style="pointer-events:none">工具依赖期 (M/L/F ≈ 0)</text>
      <text x="152" y="166" text-anchor="middle" font-size="9.5" fill="${state.selectedRegime === 'tool' ? '#F1F5F9' : '#666'}" style="pointer-events:none">尚未形成组织协调能力</text>

      <rect x="270" y="114" width="215" height="80" rx="6" fill="${state.selectedRegime === 'collapse' ? '#B84A39' : '#FEF2F2'}" stroke="#B84A39" style="cursor:pointer" data-reg="collapse"/>
      <text x="377" y="148" text-anchor="middle" font-size="11" font-weight="600" fill="${state.selectedRegime === 'collapse' ? '#fff' : '#B84A39'}" style="pointer-events:none">密度坍塌区 (Q &lt; θ)</text>
      <text x="377" y="166" text-anchor="middle" font-size="9.5" fill="${state.selectedRegime === 'collapse' ? '#FEE2E2' : '#7F1D1D'}" style="pointer-events:none">βD²/Q 吞噬毛产出</text>

      <text x="18" y="68" text-anchor="middle" font-size="10" font-weight="600" fill="#365A50" transform="rotate(-90 18 68)">高 Q</text>
      <text x="18" y="156" text-anchor="middle" font-size="10" font-weight="600" fill="#B84A39" transform="rotate(-90 18 156)">低 Q</text>
    </svg>
    <p style="margin:8px 0 0;font-size:12px;color:#252925;background:#F4F0E7;padding:8px 10px;border-radius:6px;line-height:1.5;">${regimes[state.selectedRegime] || regimes.leverage}</p>
  `
  for (const r of wrap.querySelectorAll('[data-reg]')) {
    r.addEventListener('click', () => rerender({ selectedRegime: r.getAttribute('data-reg') }))
  }
  return wrap
}

function buildResearchStructureMarkdown(state) {
  return `# OPC 研究结构与可视化方法论（从问题到结论）

> 本文档将核心研究要素（真实张力、概念边界、竞争性机制、非同源测量、可证伪性、适用边界）与《${state.title}》一一映射。

## Stage 1 · 现象与研究张力（Expectation vs. Reality）
- **核心张力**：${state.puzzle}
- **形式化张力**：期望线性扩张 $DQ - \\alpha D - \\gamma$ 与实际净绩效 $P = DQ - \\alpha D - \\frac{\\beta D^2}{Q} - \\gamma$ 之间的协调成本缺口 $\\frac{\\beta D^2}{Q}$。

## Stage 2 · 问题边界与分析单位（Scope & Units）
- **核心研究对象**：组织形态 OPC（单一最终问责核心 + 持续智能体嵌入 + M/L/F 资产积累）。
- **排除边界**：纯法律登记但无智能体编排的一人公司、传统多层级科层组织。
- **分析单位**：组织、组织—周（26周遥测面板）、关键错误/规则事件。

## Stage 3 · 因果机制与竞争性解释（Mechanism & Rivals）
\`\`\`mermaid
flowchart LR
  MLF["资产存量 M / L / F"] --> Q["协调质量 Q (门槛 θ)"]
  Q -->|调节效应| DP["净绩效 P & OPEM"]
  D["智能体密度 D"] --> DP
  R["竞争性解释: 创始人能力 / 模型跃迁 / 任务耦合"] -.->|固定效应与交互控制| DP
\`\`\`

## Stage 4 · 非同源独立测量（Non-Tautology Design）
- **自变量 / 中介（OPC-MM）**：系统遥测（APD, MCI, ELR）+ 问卷与双人独立评分（FE, BS）。
- **因变量（OPEM）**：滞后 3–6 个月的独立经营与账务记录（生存、成长、壁垒、韧性），杜绝同源偏差。

## Stage 5 · 可证伪性与稳健性检验（Falsification）
| 假设 | 预测关系 | 证伪条件 | 压力测试 |
| :--- | :--- | :--- | :--- |
| H1a/b | Q 调节 D→P，存在门槛 θ | 高/低 Q 斜率无差异或无门槛 | Hansen 门槛 + 置信区间 |
| H2a/b | MCI 改善后续交付与韧性 | 控制历史绩效后滞后项不显著 | 滞后效应 + 反向因果 |
| H3a/b | ELR 降低重复错误与恢复时间 | 规则启用后同类错误率未降 | 事件序列 + 纵向模型 |
| H4 | 任务耦合抬高门槛 θ | 高/低耦合组门槛无差异 | 三向交互 + 分行业门槛 |
| H5 | 政策经由 M/L/F 影响绩效 | 政策仅直接作用而无关 M/L/F | 中介分析 + 时序比较 |

## Stage 6 · 适用边界与三层贡献（Bounded Contribution）
- **适用边界**：高协调质量 ($Q > \\theta$) 且模块化任务下成立；低 $Q$ 高耦合下扩张会导致净绩效坍塌。
- **三层贡献**：理论（TOL 组织杠杆理论）、方法（OPC-MM 与 OPEM 分离测量）、实践（阶段与资产短板诊断）。
`
}

export function renderResearchTab(serverState) {
  const workspaceId = serverState?.workspace_id || 'workspace'
  const container = el('div', 'document-tool-content')
  container.dataset.testid = 'research-workbench'

  const draw = () => {
    const state = readState(workspaceId)
    const rerender = patch => {
      writeState(workspaceId, patch)
      draw()
    }
    container.replaceChildren()

    const intro = el('div', 'document-tool-intro with-action')
    const introText = el('div', '')
    introText.append(
      el('p', '', '将研究的 6 个核心阶段与交互式可视化工具绑定，确保论文逻辑严密而非纯文本堆砌。'),
    )
    const syncBtn = el('button', 'secondary-button', '同步到论文 (04-research-structure.md)')
    syncBtn.type = 'button'
    const status = el('span', 'status-line', '')
    syncBtn.addEventListener('click', async () => {
      syncBtn.disabled = true
      status.textContent = '正在写入 MoonBook…'
      try {
        const md = buildResearchStructureMarkdown(state)
        const blob = new Blob([md], { type: 'text/markdown' })
        const form = new FormData()
        form.append('file', blob, '04-research-structure.md')
        const res = await fetch(`/api/workspaces/${encodeURIComponent(workspaceId)}/import`, {
          method: 'POST',
          credentials: 'same-origin',
          body: JSON.stringify({
            kind: 'markdown',
            title: '04-research-structure',
            filename: 'wiki/04-research-structure.md',
            content: md,
          }),
          headers: { 'Content-Type': 'application/json' },
        })
        status.textContent = res.ok ? '已生成结构化研究文档' : `写入状态 ${res.status}`
      } catch (err) {
        status.textContent = String(err?.message || err)
      } finally {
        syncBtn.disabled = false
      }
    })
    intro.append(introText, syncBtn)
    container.append(intro)
    if (status.textContent) container.append(status)

    const stages = [
      [1, '1. 现象张力'],
      [2, '2. 边界单位'],
      [3, '3. 机制与对手'],
      [4, '4. 独立测量'],
      [5, '5. 证伪检验'],
      [6, '6. 适用边界'],
    ]
    const nav = el('div', '')
    nav.style.cssText = 'display:flex;gap:4px;flex-wrap:wrap;margin-bottom:12px;'
    for (const [num, label] of stages) {
      const b = el('button', 'secondary-button', label)
      b.type = 'button'
      if (state.activeStage === num) {
        b.style.cssText = 'background:#365A50;color:#fff;border-color:#365A50;'
      }
      b.addEventListener('click', () => rerender({ activeStage: num }))
      nav.append(b)
    }
    container.append(nav)

    const renderers = {
      1: renderStage1Tension,
      2: renderStage2Scope,
      3: renderStage3Mechanism,
      4: renderStage4Measurement,
      5: renderStage5Falsification,
      6: renderStage6Contribution,
    }
    container.append((renderers[state.activeStage] || renderStage1Tension)(state, rerender))
  }

  draw()
  return container
}
