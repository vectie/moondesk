import { spawnSync } from 'node:child_process'
import { readFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptRoot = path.dirname(fileURLToPath(import.meta.url))
const repoRoot = path.dirname(scriptRoot)
const budgetPath = path.join(scriptRoot, 'moon-warning-budget.json')
const budget = JSON.parse(readFileSync(budgetPath, 'utf8'))
const moon = process.env.MOON || 'moon'
let failed = false

function diagnostics(output) {
  const rows = []
  for (const line of output.split(/\r?\n/)) {
    try {
      const value = JSON.parse(line)
      if (value.$message_type === 'diagnostic' && value.level === 'warning') rows.push(value)
    } catch {
      // Moon also writes a human-readable completion line; it is not a diagnostic.
    }
  }
  return rows
}

for (const [name, expected] of Object.entries(budget.targets)) {
  const cwd = path.resolve(repoRoot, expected.cwd)
  const result = spawnSync(moon, [
    'check',
    '--target', expected.target,
    '--warn-list', '+unnecessary_annotation',
    '--deny-warn',
    '--output-json',
    '--diagnostic-limit', '2000',
  ], { cwd, encoding: 'utf8' })
  if (result.error || result.status !== 0) {
    failed = true
    console.error(`${name}: moon check failed`)
    console.error(result.error?.message || result.stderr || result.stdout)
    continue
  }
  const rows = diagnostics(`${result.stdout}\n${result.stderr}`)
  const actualCodes = Object.create(null)
  for (const row of rows) {
    const code = String(row.error_code)
    actualCodes[code] = (actualCodes[code] || 0) + 1
  }
  const regressions = []
  for (const [code, count] of Object.entries(actualCodes)) {
    const limit = expected.codes[code] ?? 0
    if (count > limit) regressions.push(`warning ${code}: ${count} > ${limit}`)
  }
  if (rows.length > expected.total) regressions.push(`total: ${rows.length} > ${expected.total}`)
  if (regressions.length > 0) {
    failed = true
    console.error(`${name}: warning budget regressed (${regressions.join(', ')})`)
  } else {
    const improvement = expected.total - rows.length
    console.log(`${name}: ${rows.length}/${expected.total} warnings${improvement > 0 ? ` (${improvement} below budget)` : ''}`)
  }
}

if (failed) process.exit(1)
