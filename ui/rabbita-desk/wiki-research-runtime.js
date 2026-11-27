// Domain-Agnostic 6-Stage Research Rigor & Independent Audit Workbench for MoonDesk.
// Designed around universal principles of good research (Tension, Scope, Mechanism & Rivals,
// Non-Tautology Measurement, Falsifiability, Bounded Contribution) — independent of any
// specific paper — and capable of auditing any active MoonBook manuscript against those criteria.

const STORAGE_KEY = 'moondesk.research_rigor.v2'

const UNIVERSAL_STAGES = [
  { id: 1, short: '1. 现象张力', title: 'Stage 1 · 真实张力 (Genuine Tension)', pillar: '准则 1：预期与现实的反差' },
  { id: 2, short: '2. 边界单位', title: 'Stage 2 · 概念边界与分析单位 (Scope & Unit)', pillar: '准则 2：精确边界与排除项' },
  { id: 3, short: '3. 机制与对手', title: 'Stage 3 · 因果机制与竞争性解释 (Mechanism & Rivals)', pillar: '准则 3：清晰机制与排除替代解释' },
  { id: 4, short: '4. 独立测量', title: 'Stage 4 · 非同源独立测量 (Non-Tautology)', pillar: '准则 4：自变量与因变量物理/时间隔离' },
  { id: 5, short: '5. 证伪检验', title: 'Stage 5 · 可证伪性与压力测试 (Falsifiability)', pillar: '准则 5：显式反驳条件与稳健性' },
  { id: 6, short: '6. 适用边界', title: 'Stage 6 · 有界贡献与失效区 (Bounded Contribution)', pillar: '准则 5：声明结论在何处失效' },
]

const DEFAULT_GENERIC_MODEL = {
  activeStage: 1,
  // Stage 1 generic curve parameters: Expected linear vs Reality with friction
  intensityX: 12,
  moderatorQ: 1.6,
  frictionBeta: 0.12,
  // Stage 2 generic scope focus
  selectedRing: 'core',
  selectedRq: 'RQ1',
  // Stage 3 generic DAG toggles
  showRivals: true,
  selectedNode: 'M',
  // Stage 4 generic measurement focus
  selectedSource: 'predictor',
  // Stage 5 generic hypothesis focus
  selectedHypothesis: 'H1',
  // Stage 6 generic regime focus
  selectedRegime: 'sweet_spot',
  // Independent audit state (persisted per workspace)
  audit: null,
}

function readState(workspaceId) {
  try {
    const all = JSON.parse(globalThis.localStorage?.getItem(STORAGE_KEY) || '{}')
    return { ...DEFAULT_GENERIC_MODEL, ...(all[workspaceId] || {}) }
  } catch {
    return { ...DEFAULT_GENERIC_MODEL }
  }
}

function writeState(workspaceId, patch) {
  try {
    const all = JSON.parse(globalThis.localStorage?.getItem(STORAGE_KEY) || '{}')
    const next = { ...DEFAULT_GENERIC_MODEL, ...(all[workspaceId] || {}), ...patch }
    all[workspaceId] = next
    globalThis.localStorage?.setItem(STORAGE_KEY, JSON.stringify(all))
    return next
  } catch {
    return { ...DEFAULT_GENERIC_MODEL, ...patch }
  }
}

function el(tag, className, text = '') {
  const node = document.createElement(tag)
  if (className) node.className = className
  if (text) node.textContent = text
  return node
}

function escapeHtml(text) {
  return String(text || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}

// --- Independent Paper Audit Engine (Domain-Agnostic) ---

async function collectWorkspaceMarkdownPaths(workspaceId) {
  const paths = []
  const queue = ['wiki', '']
  const seenDirs = new Set()

  while (queue.length > 0) {
    const dir = queue.shift()
    if (seenDirs.has(dir)) continue
    seenDirs.add(dir)
    try {
      const url = `/api/workspaces/${encodeURIComponent(workspaceId)}/entries${dir ? `?path=${encodeURIComponent(dir)}` : ''}`
      const res = await fetch(url)
      if (!res.ok) continue
      const entries = await res.json()
      if (!Array.isArray(entries)) continue
      for (const entry of entries) {
        if (!entry || !entry.path) continue
        if (entry.kind === 'Directory') {
          if (entry.path.startsWith('wiki') && !entry.path.includes('/figures') && !entry.path.includes('/slides')) {
            queue.push(entry.path)
          }
        } else if (
          entry.path.endsWith('.md') &&
          !entry.path.endsWith('04-research-structure.md') &&
          !entry.path.endsWith('references.md') &&
          !entry.path.endsWith('current-work.md') &&
          !entry.path.endsWith('SUMMARY.md')
        ) {
          paths.push(entry.path)
        }
      }
    } catch {
      // ignore unreachable directory
    }
  }
  return [...new Set(paths)]
}

function findSnippets(docs, regex, maxSnippets = 2) {
  const hits = []
  for (const doc of docs) {
    const lines = doc.text.split(/\r?\n/)
    for (let i = 0; i < lines.length; i += 1) {
      const line = lines[i].trim()
      if (!line || line.startsWith('```') || line.startsWith('| ---')) continue
      if (regex.test(line)) {
        const clean = line.replace(/^#+\s*/, '').slice(0, 120)
        hits.push({ file: doc.path, line: i + 1, excerpt: clean })
        if (hits.length >= maxSnippets) return hits
      }
    }
  }
  return hits
}

function evaluateDocsAgainstRigor(docs) {
  const combined = docs.map(d => d.text).join('\n')
  const totalChars = combined.length

  const checks = [
    {
      stage: 1,
      name: '现象与真实张力',
      required: '必须明确指出“常识/基线预期”与“反常现实”之间的尖锐冲突（而非仅描述背景趋势）。',
      signals: [
        { label: '反常/悖论/张力表述', re: /(悖论|反常|张力|矛盾|却反而|不升反降|坍塌|paradox|tension|puzzle|counter-?intuitive|however)/i },
        { label: '形式化或对比基线', re: /(预期|基线|线性|公式|模型|baseline|linear|expected)/i },
      ],
      gapHint: '未发现明确的反常张力或“预期 vs. 现实”分化表述，易沦为纯现状综述。',
    },
    {
      stage: 2,
      name: '概念边界与分析单位',
      required: '必须界定核心构念的操作性边界、分析单位，并显式声明“不研究什么（排除项）”。',
      signals: [
        { label: '分析单位界定', re: /(分析单位|研究对象|样本|unit of analysis|sample|level of analysis)/i },
        { label: '显式排除边界', re: /(排除|不纳入|不研究|边界|界定|exclude|out of scope|boundary|delimitation)/i },
      ],
      gapHint: '缺少显式的“排除项（Out of Scope）”或分析单位层级切分，概念容易泛化。',
    },
    {
      stage: 3,
      name: '因果机制与竞争性解释',
      required: '必须说明中介/调节机制，并正面识别与控制替代性解释（内生性、选择偏差、混杂变量）。',
      signals: [
        { label: '机制/中介/调节路径', re: /(机制|中介|调节|门槛|路径|mechanism|mediat|moderat|threshold)/i },
        { label: '竞争性解释/内生性控制', re: /(竞争性|替代解释|内生性|混杂|偏差|固定效应|安慰剂|工具变量|rival|confound|endogeneit|selection bias|alternative explanation)/i },
      ],
      gapHint: '未见系统的竞争性假说/替代解释检验（如内生性、选择偏差、遗漏变量控制）。',
    },
    {
      stage: 4,
      name: '非同源独立测量',
      required: '自变量与因变量必须来自独立数据源或时间滞后窗口，避免同源偏差与循环定义（Tautology）。',
      signals: [
        { label: '多源/独立数据隔离', re: /(独立|账务|遥测|客观|双人|盲审|滞后|independent|archival|telemetry|lagged|multi-?source)/i },
        { label: '同源偏差/构念效度防范', re: /(同源|共同方法|循环定义|构念效度|信效度|common method|tautolog|discriminant validity)/i },
      ],
      gapHint: '缺乏对“同源偏差 / 循环定义”的显式隔离设计（自变量与因变量可能源自同一批受访者或同一时点）。',
    },
    {
      stage: 5,
      name: '可证伪性与压力测试',
      required: '每个核心假设都应给出明确的“证伪条件（什么结果会推翻它）”及稳健性/压力测试。',
      signals: [
        { label: '显式证伪条件', re: /(证伪|推翻|反驳|不显著则|拒绝原假设|falsif|disprov|refut)/i },
        { label: '稳健性/敏感性分析', re: /(稳健性|敏感性|分组检验|交叉验证|bootstrap|robustness|sensitivity|placebo)/i },
      ],
      gapHint: '假设多为证实性陈述，缺少“若观测到何种反例即证伪本假设”的显式可证伪标准。',
    },
    {
      stage: 6,
      name: '有界贡献与失效区',
      required: '必须诚实标定理论失效的边界条件与局限性，而非宣称普适成立。',
      signals: [
        { label: '适用边界与失效条件', re: /(适用边界|边界条件|局限|失效|不适用|前提条件|limitation|boundary condition|scope condition|fails when)/i },
        { label: '理论/方法/实践贡献分层', re: /(理论贡献|方法贡献|实践启示|contribution|implication)/i },
      ],
      gapHint: '结论部分缺少显式的“失效区间 / 负向适用边界”声明。',
    },
  ]

  const stages = checks.map(c => {
    const matchedSignals = []
    const missingSignals = []
    const evidence = []
    for (const sig of c.signals) {
      const hits = findSnippets(docs, sig.re, 2)
      if (hits.length > 0) {
        matchedSignals.push(sig.label)
        evidence.push(...hits)
      } else {
        missingSignals.push(sig.label)
      }
    }
    let status = 'GAP'
    if (matchedSignals.length === c.signals.length) status = 'PASS'
    else if (matchedSignals.length > 0) status = 'PARTIAL'

    return {
      stage: c.stage,
      name: c.name,
      required: c.required,
      status,
      matchedSignals,
      missingSignals,
      evidence: evidence.slice(0, 3),
      gapHint: status === 'PASS' ? '' : c.gapHint,
    }
  })

  const passCount = stages.filter(s => s.status === 'PASS').length
  const partialCount = stages.filter(s => s.status === 'PARTIAL').length
  const gapCount = stages.filter(s => s.status === 'GAP').length

  return {
    auditedAt: new Date().toISOString(),
    docCount: docs.length,
    docPaths: docs.map(d => d.path),
    totalChars,
    passCount,
    partialCount,
    gapCount,
    stages,
  }
}

async function runIndependentPaperAudit(workspaceId) {
  const paths = await collectWorkspaceMarkdownPaths(workspaceId)
  const docs = []
  for (const path of paths.slice(0, 12)) {
    try {
      const res = await fetch(`/api/workspaces/${encodeURIComponent(workspaceId)}/raw?path=${encodeURIComponent(path)}`)
      if (!res.ok) continue
      const text = await res.text()
      if (text && text.trim().length > 0) {
        docs.push({ path, text })
      }
    } catch {
      // skip unreadable file
    }
  }
  return evaluateDocsAgainstRigor(docs)
}

// --- Stage Visualizers (Domain-Agnostic, Model-Driven) ---

function renderStage1Tension(state, rerender) {
  const wrap = el('div', 'research-stage-viz')
  const X = Number(state.intensityX) || 12
  const Q = Number(state.moderatorQ) || 1.6
  const beta = Number(state.frictionBeta) || 0.12
  const alpha = 0.55
  const gamma = 1.5

  const calcLinear = x => x * Q - alpha * x - gamma
  const calcActual = x => x * Q - alpha * x - (beta * x * x) / Q - gamma

  const W = 480
  const H = 225
  const padL = 48
  const padR = 20
  const padT = 22
  const padB = 34
  const plotW = W - padL - padR
  const plotH = H - padT - padB
  const maxX = 20
  const minY = -20
  const maxY = 45

  const px = x => padL + (x / maxX) * plotW
  const py = y => padT + ((maxY - Math.max(minY, Math.min(maxY, y))) / (maxY - minY)) * plotH

  const ptsLin = []
  const ptsAct = []
  for (let i = 0; i <= 40; i += 1) {
    const x = (i / 40) * maxX
    ptsLin.push(`${px(x).toFixed(1)},${py(calcLinear(x)).toFixed(1)}`)
    ptsAct.push(`${px(x).toFixed(1)},${py(calcActual(x)).toFixed(1)}`)
  }

  const curLin = calcLinear(X)
  const curAct = calcActual(X)
  const gap = Math.max(0, curLin - curAct)
  const yZero = py(0).toFixed(1)

  wrap.innerHTML = `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;gap:8px;flex-wrap:wrap;">
      <strong style="font-size:13px;color:#252925;">通用张力模型：基线预期 vs. 非线性现实</strong>
      <span style="font-size:11px;padding:2px 8px;border-radius:999px;background:#FDECE8;color:#B84A39;font-weight:600;">
        理论缺口 Δ = ${gap.toFixed(1)}
      </span>
    </div>
    <svg viewBox="0 0 ${W} ${H}" style="width:100%;height:auto;background:#FCFBF8;border:1px solid #E2DDD3;border-radius:8px;display:block;">
      <line x1="${padL}" y1="${yZero}" x2="${W - padR}" y2="${yZero}" stroke="#C9C2B6" stroke-dasharray="4 3" />
      <text x="${padL - 6}" y="${Number(yZero) + 4}" text-anchor="end" font-size="10" fill="#7A766E">0</text>
      <line x1="${padL}" y1="${padT}" x2="${padL}" y2="${H - padB}" stroke="#9E988E" />
      <line x1="${padL}" y1="${H - padB}" x2="${W - padR}" y2="${H - padB}" stroke="#9E988E" />
      <text x="${padL + plotW / 2}" y="${H - 8}" text-anchor="middle" font-size="10.5" fill="#5D5952">驱动强度 / 投入规模 X = ${X}（当前实际结果 Y = ${curAct.toFixed(1)}）</text>
      <text x="14" y="${padT + plotH / 2}" text-anchor="middle" font-size="10.5" fill="#5D5952" transform="rotate(-90 14 ${padT + plotH / 2})">净结果 Y</text>

      <polyline fill="none" stroke="#8C9991" stroke-width="2" stroke-dasharray="5 4" points="${ptsLin.join(' ')}" />
      <polyline fill="none" stroke="#365A50" stroke-width="2.6" points="${ptsAct.join(' ')}" />

      <line x1="${px(X).toFixed(1)}" y1="${py(curLin).toFixed(1)}" x2="${px(X).toFixed(1)}" y2="${py(curAct).toFixed(1)}" stroke="#B84A39" stroke-width="2" />
      <circle cx="${px(X).toFixed(1)}" cy="${py(curLin).toFixed(1)}" r="4" fill="#8C9991" />
      <circle cx="${px(X).toFixed(1)}" cy="${py(curAct).toFixed(1)}" r="4.5" fill="#365A50" />
      <text x="${Math.min(W - 72, px(X) + 6).toFixed(1)}" y="${((py(curLin) + py(curAct)) / 2).toFixed(1)}" font-size="10" font-weight="600" fill="#B84A39">Δ=${gap.toFixed(1)}</text>

      <text x="${padL + 8}" y="${padT + 14}" font-size="10" fill="#6F7A73">-- 朴素线性预期 (无摩擦)</text>
      <text x="${padL + 8}" y="${padT + 28}" font-size="10" font-weight="600" fill="#365A50">― 实际系统响应 (含非线性摩擦 βX²/M)</text>
    </svg>
    <div style="display:flex;gap:12px;align-items:center;margin-top:10px;flex-wrap:wrap;font-size:12px;color:#454944;">
      <label style="display:flex;align-items:center;gap:6px;">
        <span>强度 X:</span>
        <input type="range" min="1" max="20" value="${X}" data-role="x-slider" style="width:110px;">
        <strong>${X}</strong>
      </label>
      <div style="display:flex;align-items:center;gap:4px;">
        <span>调节能力 M:</span>
        ${[0.8, 1.6, 3.2].map(val => `<button type="button" data-q="${val}" class="${Q === val ? 'primary-button' : 'secondary-button'}" style="padding:2px 8px;font-size:11px;">M=${val}</button>`).join('')}
      </div>
    </div>
  `
  const slider = wrap.querySelector('[data-role="x-slider"]')
  slider?.addEventListener('input', e => rerender({ intensityX: Number(e.target.value) }))
  for (const btn of wrap.querySelectorAll('[data-q]')) {
    btn.addEventListener('click', () => rerender({ moderatorQ: Number(btn.getAttribute('data-q')) }))
  }
  return wrap
}

function renderStage2Scope(state, rerender) {
  const wrap = el('div', 'research-stage-viz')
  const ringNotes = {
    core: '核心分析单位 (Core Unit)：明确直接观测与因果推断的主体（例如个体-任务闭环、组织-周面板），避免分析单位混淆。',
    context: '情境边界 (Contextual Boundary)：限定研究结论成立的历史、行业或技术条件，避免把特定情境当成无条件定律。',
    outer: '显式排除项 (Out of Scope)：必须写明“不研究什么”，防止概念过度膨胀导致无法证伪。',
  }
  const rqNotes = {
    RQ1: 'RQ1（描述/分类问题）：核心构念的操作性定义与判别边界是什么？',
    RQ2: 'RQ2（机制/因果问题）：核心驱动因素通过何种中介/调节机制影响结果？',
    RQ3: 'RQ3（边界/异质性问题）：上述机制在何种情境下强化、逆转或失效？',
  }
  const ringColor = key => (state.selectedRing === key ? '#365A50' : '#D9D3C7')
  const ringFill = key => (state.selectedRing === key ? 'rgba(54, 90, 80, 0.14)' : 'rgba(245, 242, 235, 0.7)')

  wrap.innerHTML = `
    <strong style="font-size:13px;color:#252925;display:block;margin-bottom:8px;">通用边界同心圆：分析单位与显式排除</strong>
    <svg viewBox="0 0 480 215" style="width:100%;height:auto;background:#FCFBF8;border:1px solid #E2DDD3;border-radius:8px;display:block;">
      <ellipse cx="240" cy="108" rx="210" ry="92" fill="${ringFill('outer')}" stroke="${ringColor('outer')}" stroke-width="2" stroke-dasharray="5 4" data-ring="outer" style="cursor:pointer;" />
      <text x="240" y="34" text-anchor="middle" font-size="10.5" fill="#5D5952" style="pointer-events:none;">外围排除区 (Out of Scope：明确不纳入解释的变量)</text>

      <ellipse cx="240" cy="116" rx="150" ry="66" fill="${ringFill('context')}" stroke="${ringColor('context')}" stroke-width="2" data-ring="context" style="cursor:pointer;" />
      <text x="240" y="69" text-anchor="middle" font-size="10.5" fill="#42544D" style="pointer-events:none;">情境样本边界 (Contextual Sample)</text>

      <ellipse cx="240" cy="126" rx="92" ry="40" fill="${ringFill('core')}" stroke="${ringColor('core')}" stroke-width="2.4" data-ring="core" style="cursor:pointer;" />
      <text x="240" y="124" text-anchor="middle" font-size="11.5" font-weight="600" fill="#252925" style="pointer-events:none;">核心分析单位</text>
      <text x="240" y="140" text-anchor="middle" font-size="9.5" fill="#4F544E" style="pointer-events:none;">Core Unit of Analysis</text>
    </svg>
    <div style="display:flex;gap:6px;margin-top:8px;flex-wrap:wrap;">
      ${Object.keys(rqNotes).map(rq => `<button type="button" data-rq="${rq}" class="${state.selectedRq === rq ? 'primary-button' : 'secondary-button'}" style="padding:3px 9px;font-size:11px;">${rq}</button>`).join('')}
    </div>
    <p style="margin:8px 0 0;font-size:12px;color:#3E423D;background:#F4F0E7;padding:8px 10px;border-radius:6px;line-height:1.5;">
      <strong>边界要求：</strong>${ringNotes[state.selectedRing] || ringNotes.core}<br>
      <strong>问题映射：</strong>${rqNotes[state.selectedRq] || rqNotes.RQ1}
    </p>
  `
  for (const r of wrap.querySelectorAll('[data-ring]')) {
    r.addEventListener('click', () => rerender({ selectedRing: r.getAttribute('data-ring') }))
  }
  for (const b of wrap.querySelectorAll('[data-rq]')) {
    b.addEventListener('click', () => rerender({ selectedRq: b.getAttribute('data-rq') }))
  }
  return wrap
}

function renderStage3Mechanism(state, rerender) {
  const wrap = el('div', 'research-stage-viz')
  const showRivals = state.showRivals !== false
  const nodeNotes = {
    M: '核心机制路径 (Mediator/Mechanism)：解释“为什么 X 会导致 Y”，而非仅仅展示相关性。',
    X: '关键自变量 (Driver X)：必须独立于结果测量，避免事后倒推。',
    Y: '目标因变量 (Outcome Y)：应具备客观可验证性或时间滞后性。',
    Rivals: '竞争性解释 (Rival Pathways)：如选择偏差、能力混杂、外部冲击；好研究必须证明其不能完全吸收主效应。',
  }

  wrap.innerHTML = `
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;gap:8px;">
      <strong style="font-size:13px;color:#252925;">通用因果机制与竞争假说 DAG</strong>
      <button type="button" data-role="toggle-rivals" class="secondary-button" style="padding:2px 8px;font-size:11px;">${showRivals ? '隐藏竞争性解释' : '显示竞争性解释'}</button>
    </div>
    <svg viewBox="0 0 480 210" style="width:100%;height:auto;background:#FCFBF8;border:1px solid #E2DDD3;border-radius:8px;display:block;">
      <defs>
        <marker id="res-arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
          <path d="M 0 1 L 10 5 L 0 9 z" fill="#365A50" />
        </marker>
        <marker id="res-arrow-rival" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
          <path d="M 0 1 L 10 5 L 0 9 z" fill="#B84A39" />
        </marker>
      </defs>

      <line x1="126" y1="68" x2="188" y2="68" stroke="#365A50" stroke-width="2" marker-end="url(#res-arrow)" />
      <line x1="296" y1="68" x2="346" y2="104" stroke="#365A50" stroke-width="2" marker-end="url(#res-arrow)" />
      <line x1="126" y1="142" x2="344" y2="122" stroke="#365A50" stroke-width="2" marker-end="url(#res-arrow)" />
      ${showRivals ? `<line x1="238" y1="168" x2="348" y2="132" stroke="#B84A39" stroke-width="1.8" stroke-dasharray="4 3" marker-end="url(#res-arrow-rival)" />` : ''}

      <g data-node="X" style="cursor:pointer;">
        <rect x="20" y="122" width="106" height="44" rx="8" fill="${state.selectedNode === 'X' ? '#365A50' : '#EFECE4'}" stroke="#365A50" stroke-width="1.5" />
        <text x="73" y="142" text-anchor="middle" font-size="11" font-weight="600" fill="${state.selectedNode === 'X' ? '#fff' : '#252925'}">核心自变量 X</text>
        <text x="73" y="157" text-anchor="middle" font-size="9.5" fill="${state.selectedNode === 'X' ? '#E4EFEA' : '#5D5952'}">Driver / Exposure</text>
      </g>

      <g data-node="M" style="cursor:pointer;">
        <rect x="20" y="42" width="106" height="48" rx="8" fill="${state.selectedNode === 'M' ? '#365A50' : '#E7F0EC'}" stroke="#365A50" stroke-width="1.5" />
        <text x="73" y="63" text-anchor="middle" font-size="11" font-weight="600" fill="${state.selectedNode === 'M' ? '#fff' : '#252925'}">机制要素 M</text>
        <text x="73" y="79" text-anchor="middle" font-size="9.5" fill="${state.selectedNode === 'M' ? '#E4EFEA' : '#365A50'}">Mechanism</text>
      </g>

      <g data-node="M" style="cursor:pointer;">
        <rect x="190" y="42" width="106" height="48" rx="8" fill="${state.selectedNode === 'M' ? '#365A50' : '#E7F0EC'}" stroke="#365A50" stroke-width="1.8" />
        <text x="243" y="63" text-anchor="middle" font-size="11" font-weight="600" fill="${state.selectedNode === 'M' ? '#fff' : '#252925'}">协调/调节品质 Q</text>
        <text x="243" y="79" text-anchor="middle" font-size="9.5" fill="${state.selectedNode === 'M' ? '#E4EFEA' : '#365A50'}">Threshold θ?</text>
      </g>

      <g data-node="Y" style="cursor:pointer;">
        <rect x="350" y="94" width="112" height="50" rx="8" fill="${state.selectedNode === 'Y' ? '#365A50' : '#EFECE4'}" stroke="#365A50" stroke-width="1.8" />
        <text x="406" y="116" text-anchor="middle" font-size="11" font-weight="600" fill="${state.selectedNode === 'Y' ? '#fff' : '#252925'}">独立结果 Y</text>
        <text x="406" y="132" text-anchor="middle" font-size="9.5" fill="${state.selectedNode === 'Y' ? '#E4EFEA' : '#5D5952'}">Outcome</text>
      </g>

      ${showRivals ? `
      <g data-node="Rivals" style="cursor:pointer;">
        <rect x="138" y="162" width="146" height="36" rx="8" fill="#FDECE8" stroke="#B84A39" stroke-width="1.5" stroke-dasharray="4 3" />
        <text x="211" y="184" text-anchor="middle" font-size="10.5" font-weight="600" fill="#B84A39">竞争性解释 (Rivals / Confounders)</text>
      </g>` : ''}
    </svg>
    <p style="margin:8px 0 0;font-size:12px;color:#3E423D;background:#F4F0E7;padding:8px 10px;border-radius:6px;line-height:1.5;">
      ${nodeNotes[state.selectedNode] || nodeNotes.M}
    </p>
  `
  wrap.querySelector('[data-role="toggle-rivals"]')?.addEventListener('click', () => rerender({ showRivals: !showRivals }))
  for (const n of wrap.querySelectorAll('[data-node]')) {
    n.addEventListener('click', () => rerender({ selectedNode: n.getAttribute('data-node') }))
  }
  return wrap
}

function renderStage4Measurement(state, rerender) {
  const wrap = el('div', 'research-stage-viz')
  const details = {
    predictor: '自变量/机制测量端 (X / M)：必须基于行为日志、协议文本或独立事前编码，不得混入结果绩效指标。',
    barrier: '隔离屏障 (Non-Tautology Barrier)：通过物理数据源分离、时间滞后 (t₀ → t₀+Δt) 与盲审消除同源偏差。',
    outcome: '因变量测量端 (Y)：必须来自独立外部记录（如客观产出、账务/留存、第三方评估），绝不可用“主观自我感觉良好”验证“能力强”。',
  }
  const active = state.selectedSource || 'predictor'

  wrap.innerHTML = `
    <strong style="font-size:13px;color:#252925;display:block;margin-bottom:8px;">非同源双源隔离图 (Anti-Tautology Design)</strong>
    <svg viewBox="0 0 480 200" style="width:100%;height:auto;background:#FCFBF8;border:1px solid #E2DDD3;border-radius:8px;display:block;">
      <g data-src="predictor" style="cursor:pointer;">
        <rect x="16" y="24" width="136" height="148" rx="8" fill="${active === 'predictor' ? '#E7F0EC' : '#F4F0E7'}" stroke="#365A50" stroke-width="${active === 'predictor' ? '2.2' : '1.2'}" />
        <text x="84" y="48" text-anchor="middle" font-size="11" font-weight="600" fill="#252925">自变量测量端 (t₀)</text>
        <text x="84" y="84" text-anchor="middle" font-size="10" fill="#365A50">行为日志 / 结构化编码</text>
        <text x="84" y="106" text-anchor="middle" font-size="10" fill="#365A50">事前问卷 / 协议文本</text>
        <text x="84" y="148" text-anchor="middle" font-size="9.5" fill="#5D5952">仅测量“投入与能力”</text>
      </g>

      <g data-src="barrier" style="cursor:pointer;">
        <rect x="174" y="34" width="132" height="128" rx="8" fill="${active === 'barrier' ? '#FDECE8' : '#FAF7F0'}" stroke="#B84A39" stroke-width="${active === 'barrier' ? '2.2' : '1.4'}" stroke-dasharray="5 3" />
        <text x="240" y="64" text-anchor="middle" font-size="11" font-weight="600" fill="#B84A39">独立数据源屏障</text>
        <text x="240" y="96" text-anchor="middle" font-size="10" fill="#5D5952">• 时间滞后 (t₀ + Δt)</text>
        <text x="240" y="116" text-anchor="middle" font-size="10" fill="#5D5952">• 盲审 / 双评分</text>
        <text x="240" y="136" text-anchor="middle" font-size="10" fill="#5D5952">• 禁止同源共享偏差</text>
      </g>

      <g data-src="outcome" style="cursor:pointer;">
        <rect x="328" y="24" width="136" height="148" rx="8" fill="${active === 'outcome' ? '#E7F0EC' : '#F4F0E7'}" stroke="#365A50" stroke-width="${active === 'outcome' ? '2.2' : '1.2'}" />
        <text x="396" y="48" text-anchor="middle" font-size="11" font-weight="600" fill="#252925">因变量测量端 (t₁)</text>
        <text x="396" y="84" text-anchor="middle" font-size="10" fill="#365A50">独立商业/系统记录</text>
        <text x="396" y="106" text-anchor="middle" font-size="10" fill="#365A50">外部留存 / 客观返工率</text>
        <text x="396" y="148" text-anchor="middle" font-size="9.5" fill="#5D5952">仅测量“真实结果”</text>
      </g>
    </svg>
    <p style="margin:8px 0 0;font-size:12px;color:#3E423D;background:#F4F0E7;padding:8px 10px;border-radius:6px;line-height:1.5;">
      ${details[active]}
    </p>
  `
  for (const node of wrap.querySelectorAll('[data-src]')) {
    node.addEventListener('click', () => rerender({ selectedSource: node.getAttribute('data-src') }))
  }
  return wrap
}

function renderStage5Falsification(state, rerender) {
  const wrap = el('div', 'research-stage-viz')
  const items = [
    {
      id: 'H1',
      label: 'H1 主效应与门槛',
      prediction: '核心驱动 X 在低/高调节组之间呈现显著斜率反转或非线性门槛 θ。',
      falsifier: '若低调节组随 X 增加仍单调递增且无统计拐点，则核心张力假说被证伪。',
      stress: '门槛回归 + 分位数检验 + 置信区间估计',
    },
    {
      id: 'H2',
      label: 'H2 中介机制排他性',
      prediction: '提出的中介机制 M 在控制竞争性变量后仍解释显著增量方差。',
      falsifier: '若加入基线经验/外部能力控制后 M 的系数归零，则机制归因被证伪。',
      stress: '巢式模型 AIC/BIC 比较 + 工具变量/面板固定效应',
    },
    {
      id: 'H3',
      label: 'H3 边界调节检验',
      prediction: '任务复杂度/情境压力显著放大机制 M 对结果 Y 的边际效应。',
      falsifier: '若简单任务与高复杂度任务子样本中 M 的斜率无统计差异，则边界条件被证伪。',
      stress: '分组交互项检验 + 倾向得分匹配',
    },
  ]
  const active = items.find(i => i.id === state.selectedHypothesis) || items[0]

  wrap.innerHTML = `
    <strong style="font-size:13px;color:#252925;display:block;margin-bottom:8px;">可证伪性矩阵 (Falsifiability & Stress Tests)</strong>
    <div style="display:flex;gap:6px;flex-wrap:wrap;margin-bottom:10px;">
      ${items.map(i => `<button type="button" data-hyp="${i.id}" class="${active.id === i.id ? 'primary-button' : 'secondary-button'}" style="padding:3px 9px;font-size:11px;">${i.label}</button>`).join('')}
    </div>
    <div style="border:1px solid #E2DDD3;border-radius:8px;padding:12px;background:#FCFBF8;font-size:12px;line-height:1.55;">
      <div><strong>预测信号：</strong>${active.prediction}</div>
      <div style="margin-top:6px;color:#B84A39;"><strong>显式证伪条件（什么会推翻它）：</strong>${active.falsifier}</div>
      <div style="margin-top:6px;color:#365A50;"><strong>压力测试与稳健性：</strong>${active.stress}</div>
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
    sweet_spot: '有效高杠杆区 (High M × Complex Context)：机制成立且产生显著增量价值——这是论文的核心有效范围。',
    over_eng: '边际溢出区 (High M × Simple Context)：简单问题无需复杂机制，过度设计反而增加不必要摩擦。',
    baseline: '平庸基线区 (Low M × Simple Context)：常规工具即可跑通，研究机制在此处不产生差异化。',
    collapse: '失控/失效区 (Low M × Complex Context)：机制缺失下盲目扩张导致系统返工与绩效坍塌（理论负向边界）。',
  }
  const active = state.selectedRegime || 'sweet_spot'

  wrap.innerHTML = `
    <strong style="font-size:13px;color:#252925;display:block;margin-bottom:8px;">2×2 适用边界矩阵 (Where Claims Hold vs. Fail)</strong>
    <svg viewBox="0 0 480 205" style="width:100%;height:auto;background:#FCFBF8;border:1px solid #E2DDD3;border-radius:8px;display:block;">
      <text x="155" y="18" text-anchor="middle" font-size="10.5" font-weight="600" fill="#4F544E">低复杂度 / 独立情境</text>
      <text x="365" y="18" text-anchor="middle" font-size="10.5" font-weight="600" fill="#4F544E">高复杂度 / 强耦合情境</text>

      <rect x="44" y="28" width="206" height="76" rx="6" fill="${active === 'over_eng' ? '#365A50' : '#EFECE4'}" stroke="#C9C2B6" data-reg="over_eng" style="cursor:pointer;" />
      <text x="147" y="62" text-anchor="middle" font-size="11" font-weight="600" fill="${active === 'over_eng' ? '#fff' : '#252925'}" style="pointer-events:none">边际溢出区</text>
      <text x="147" y="80" text-anchor="middle" font-size="9.5" fill="${active === 'over_eng' ? '#E4EFEA' : '#5D5952'}" style="pointer-events:none">高机制投入回报递减</text>

      <rect x="260" y="28" width="206" height="76" rx="6" fill="${active === 'sweet_spot' ? '#365A50' : '#E7F0EC'}" stroke="#365A50" stroke-width="1.8" data-reg="sweet_spot" style="cursor:pointer;" />
      <text x="363" y="62" text-anchor="middle" font-size="11" font-weight="600" fill="${active === 'sweet_spot' ? '#fff' : '#252925'}" style="pointer-events:none">核心有效区 (Sweet Spot)</text>
      <text x="363" y="80" text-anchor="middle" font-size="9.5" fill="${active === 'sweet_spot' ? '#E4EFEA' : '#365A50'}" style="pointer-events:none">理论成立并产生显著杠杆</text>

      <rect x="44" y="114" width="206" height="76" rx="6" fill="${active === 'baseline' ? '#5D5952' : '#F5F2EB'}" stroke="#C9C2B6" data-reg="baseline" style="cursor:pointer;" />
      <text x="147" y="148" text-anchor="middle" font-size="11" font-weight="600" fill="${active === 'baseline' ? '#fff' : '#252925'}" style="pointer-events:none">平庸基线区</text>
      <text x="147" y="166" text-anchor="middle" font-size="9.5" fill="${active === 'baseline' ? '#EFECE4' : '#5D5952'}" style="pointer-events:none">常规脚本即可覆盖</text>

      <rect x="260" y="114" width="206" height="76" rx="6" fill="${active === 'collapse' ? '#B84A39' : '#FDECE8'}" stroke="#B84A39" stroke-width="1.6" data-reg="collapse" style="cursor:pointer;" />
      <text x="363" y="148" text-anchor="middle" font-size="11" font-weight="600" fill="${active === 'collapse' ? '#fff' : '#B84A39'}" style="pointer-events:none">失效 / 坍塌区 (Failure Bound)</text>
      <text x="363" y="166" text-anchor="middle" font-size="9.5" fill="${active === 'collapse' ? '#FEE2E2' : '#7F1D1D'}" style="pointer-events:none">盲目扩张导致系统过载</text>

      <text x="18" y="66" text-anchor="middle" font-size="10" font-weight="600" fill="#365A50" transform="rotate(-90 18 66)">高 M</text>
      <text x="18" y="152" text-anchor="middle" font-size="10" font-weight="600" fill="#B84A39" transform="rotate(-90 18 152)">低 M</text>
    </svg>
    <p style="margin:8px 0 0;font-size:12px;color:#252925;background:#F4F0E7;padding:8px 10px;border-radius:6px;line-height:1.5;">${regimes[active]}</p>
  `
  for (const r of wrap.querySelectorAll('[data-reg]')) {
    r.addEventListener('click', () => rerender({ selectedRegime: r.getAttribute('data-reg') }))
  }
  return wrap
}

function renderStageAuditBox(audit, stageId) {
  const box = el('div', '')
  box.style.cssText = 'margin-top:12px;border:1px solid #DFD9CE;border-radius:8px;padding:10px 12px;background:#FAF8F3;'

  if (!audit) {
    box.innerHTML = `
      <div style="font-size:12px;color:#5D5952;line-height:1.5;">
        <strong>独立审稿未运行：</strong>点击上方「独立检验当前论文」按钮，系统将读取当前 MoonBook 实际正文（不含结构摘要），独立检验该阶段是否真正达标。
      </div>
    `
    return box
  }

  const s = (audit.stages || []).find(item => item.stage === stageId)
  if (!s) return box

  const badgeStyle =
    s.status === 'PASS'
      ? 'background:#E6F2EC;color:#275946;'
      : s.status === 'PARTIAL'
      ? 'background:#FDF4E3;color:#8E5C13;'
      : 'background:#FDECE8;color:#B84A39;'
  const badgeText = s.status === 'PASS' ? 'PASS · 达标' : s.status === 'PARTIAL' ? 'PARTIAL · 待加强' : 'GAP · 存在缺口'

  const evHtml = s.evidence.length
    ? s.evidence.map(e => `<li style="margin:3px 0;"><code>${escapeHtml(e.file)}:${e.line}</code> — ${escapeHtml(e.excerpt)}</li>`).join('')
    : '<li style="color:#8C867C;">未在正文中检索到该阶段的直接文本证据。</li>'

  box.innerHTML = `
    <div style="display:flex;justify-content:space-between;align-items:center;gap:8px;margin-bottom:6px;">
      <strong style="font-size:12px;color:#252925;">当前论文独立体检（Stage ${stageId}）</strong>
      <span style="font-size:11px;font-weight:600;padding:2px 8px;border-radius:999px;${badgeStyle}">${badgeText}</span>
    </div>
    <div style="font-size:11.5px;color:#4F544E;margin-bottom:6px;"><strong>好研究标准：</strong>${escapeHtml(s.required)}</div>
    ${s.gapHint ? `<div style="font-size:11.5px;color:#B84A39;background:#FDECE8;padding:6px 8px;border-radius:6px;margin-bottom:6px;"><strong>发现问题：</strong>${escapeHtml(s.gapHint)}</div>` : ''}
    <div style="font-size:11.5px;color:#3E423D;">
      <strong>正文证据检索：</strong>
      <ul style="margin:4px 0 0 16px;padding:0;">${evHtml}</ul>
    </div>
  `
  return box
}

function buildAuditMarkdownReport(audit) {
  if (!audit) return ''
  const rows = (audit.stages || [])
    .map(s => `| Stage ${s.stage} · ${s.name} | **${s.status}** | ${s.matchedSignals.join('、') || '无'} | ${s.missingSignals.join('、') || '无'} | ${s.gapHint || '已满足基本严谨性要求'} |`)
    .join('\n')

  return `# 独立研究严谨性体检报告（Independent Research Rigor Audit）

> 本报告由 MoonDesk **通用研究严谨性引擎** 独立扫描当前 MoonBook 实际正文（共 ${audit.docCount} 份文档，跳过结构摘要本身）生成，用于检验当前研究是否真正符合好研究的 6 阶段标准。

- **扫描文档**：${audit.docPaths.map(p => `\`${p}\``).join(', ')}
- **综合得分**：**${audit.passCount} / 6 达标**（${audit.partialCount} 待加强，${audit.gapCount} 缺失）

| 阶段 | 独立判定 | 已检出要素 | 缺失要素 | 诊断意见 |
| :--- | :--- | :--- | :--- | :--- |
${rows}
`
}

export function renderResearchTab(serverState) {
  const workspaceId = serverState?.workspace_id || 'workspace'
  const container = el('div', 'document-tool-content')
  container.dataset.testid = 'research-workbench'
  let auditing = false

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
      el('p', '', '基于通用好研究标准（而非迁就既有草稿）构建 6 阶段模型，并独立检验当前论文是否真正严谨。'),
    )
    const actionRow = el('div', '')
    actionRow.style.cssText = 'display:flex;gap:6px;flex-wrap:wrap;align-items:center;'

    const auditBtn = el('button', 'primary-button', auditing ? '正在独立扫描正文…' : '独立检验当前论文')
    auditBtn.type = 'button'
    auditBtn.disabled = auditing
    auditBtn.dataset.testid = 'research-run-audit'

    const syncBtn = el('button', 'secondary-button', '导出体检报告')
    syncBtn.type = 'button'
    syncBtn.disabled = !state.audit

    const status = el('span', 'status-line', '')

    auditBtn.addEventListener('click', async () => {
      auditing = true
      draw()
      try {
        const audit = await runIndependentPaperAudit(workspaceId)
        writeState(workspaceId, { audit })
      } finally {
        auditing = false
        draw()
      }
    })

    syncBtn.addEventListener('click', async () => {
      if (!state.audit) return
      syncBtn.disabled = true
      status.textContent = '正在导出体检报告…'
      try {
        const md = buildAuditMarkdownReport(state.audit)
        const blob = new Blob([md], { type: 'text/markdown;charset=utf-8' })
        const url = URL.createObjectURL(blob)
        const a = document.createElement('a')
        a.href = url
        a.download = `${workspaceId}-rigor-audit.md`
        document.body.appendChild(a)
        a.click()
        a.remove()
        URL.revokeObjectURL(url)
        status.textContent = '已下载独立体检报告'
      } catch {
        status.textContent = '导出失败'
      } finally {
        syncBtn.disabled = false
      }
    })

    actionRow.append(auditBtn, syncBtn, status)
    intro.append(introText, actionRow)
    container.append(intro)

    if (state.audit) {
      const score = el('div', '')
      score.style.cssText = 'display:flex;justify-content:space-between;align-items:center;padding:8px 10px;border-radius:8px;background:#EFECE4;margin-bottom:10px;font-size:12px;'
      score.innerHTML = `
        <span>已独立扫描 <strong>${state.audit.docCount}</strong> 份正文文档（不含摘要自证）</span>
        <span><strong>${state.audit.passCount}/6</strong> 达标 · <span style="color:#8E5C13;">${state.audit.partialCount} 待加强</span> · <span style="color:#B84A39;">${state.audit.gapCount} 缺口</span></span>
      `
      container.append(score)
    }

    const nav = el('div', '')
    nav.style.cssText = 'display:flex;gap:6px;flex-wrap:wrap;margin-bottom:12px;'
    for (const s of UNIVERSAL_STAGES) {
      const auditStage = state.audit?.stages?.find(item => item.stage === s.id)
      const marker = auditStage ? (auditStage.status === 'PASS' ? ' ✓' : auditStage.status === 'PARTIAL' ? ' !' : ' ✗') : ''
      const btn = el('button', state.activeStage === s.id ? 'primary-button' : 'secondary-button', `${s.short}${marker}`)
      btn.type = 'button'
      btn.style.cssText = 'padding:4px 9px;font-size:11.5px;'
      btn.addEventListener('click', () => rerender({ activeStage: s.id }))
      nav.append(btn)
    }
    container.append(nav)

    const current = UNIVERSAL_STAGES.find(s => s.id === state.activeStage) || UNIVERSAL_STAGES[0]
    const header = el('div', '')
    header.style.cssText = 'margin-bottom:10px;padding-bottom:8px;border-bottom:1px solid #E2DDD3;'
    const title = el('h3', '', current.title)
    title.style.cssText = 'margin:0 0 4px;font-size:14px;color:#252925;'
    const pillar = el('span', '', current.pillar)
    pillar.style.cssText = 'font-size:11.5px;color:#365A50;font-weight:600;'
    header.append(title, pillar)
    container.append(header)

    const renderers = {
      1: renderStage1Tension,
      2: renderStage2Scope,
      3: renderStage3Mechanism,
      4: renderStage4Measurement,
      5: renderStage5Falsification,
      6: renderStage6Contribution,
    }
    container.append(renderers[current.id](state, rerender))
    container.append(renderStageAuditBox(state.audit, current.id))
  }

  draw()
  return container
}
