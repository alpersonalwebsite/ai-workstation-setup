// Validate every in-repo markdown anchor link against the headings it targets.
//
// THE SLUG RULES ARE NOT REIMPLEMENTED HERE, ON PURPOSE. A hand-rolled version is
// exactly what let two broken anchors ship green: it collapsed the double space
// left behind by removing "(+" or "/" into ONE hyphen, where GitHub emits two, so
// #tmux-resurrect-... was generated for a heading whose real id is
// #tmux--resurrect-... . Checking hand-made slugs against hand-made rules passes
// by construction and proves nothing. github-slugger is the library GitHub uses.
import GithubSlugger from 'github-slugger'
import { readFileSync, existsSync } from 'node:fs'
import { dirname, resolve } from 'node:path'

const files = process.argv.slice(2)
const idsOf = new Map()

function headingIds(file) {
  if (idsOf.has(file)) return idsOf.get(file)
  const slugger = new GithubSlugger()
  const ids = new Set()
  for (const line of readFileSync(file, 'utf8').split('\n')) {
    const m = /^(#{1,6})\s+(.*)$/.exec(line)
    if (!m) continue
    // Slug the RENDERED text: link syntax and inline-code backticks are gone by then.
    const text = m[2].replace(/\[([^\]]*)\]\([^)]*\)/g, '$1').replace(/`/g, '')
    ids.add(slugger.slug(text))
  }
  idsOf.set(file, ids)
  return ids
}

let dead = 0
let checked = 0
for (const file of files) {
  const md = readFileSync(file, 'utf8')
  for (const [, target] of md.matchAll(/\]\(([^)\s]*#[^)\s]+)\)/g)) {
    const [path, anchor] = target.split('#')
    const inFile = path === '' ? file : resolve(dirname(file), path)
    if (!existsSync(inFile)) continue           // the link job already covers dead paths
    if (!/\.md$/.test(inFile)) continue
    checked++
    if (!headingIds(inFile).has(anchor)) {
      console.log(`::error file=${file}::dead anchor #${anchor}` +
                  (path ? ` in ${path}` : '') + ' (no heading generates that id)')
      dead++
    }
  }
}
console.log(`checked ${checked} anchor link(s) across ${files.length} file(s), ${dead} dead`)
process.exit(dead ? 1 : 0)
