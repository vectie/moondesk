// A real TypeScript language service over source buffers the user has opened.
// It intentionally reports its open-buffer scope rather than claiming a project build.
import ts from 'typescript'

export function createOpenBufferTypeScriptService() {
  const files = new Map()
  const options = { target: ts.ScriptTarget.ESNext, module: ts.ModuleKind.ESNext, allowJs: true, checkJs: true, jsx: ts.JsxEmit.Preserve, noLib: true, allowNonTsExtensions: true }
  const host = {
    getScriptFileNames: () => [...files.keys()],
    getScriptVersion: path => String(files.get(path)?.version || 0),
    getScriptSnapshot: path => files.has(path) ? ts.ScriptSnapshot.fromString(files.get(path).text) : undefined,
    getCurrentDirectory: () => '/',
    getCompilationSettings: () => options,
    getDefaultLibFileName: () => '/lib.d.ts',
    fileExists: path => files.has(path), readFile: path => files.get(path)?.text,
    readDirectory: () => [...files.keys()], directoryExists: () => true,
  }
  const service = ts.createLanguageService(host, ts.createDocumentRegistry())
  const name = path => path.startsWith('/') ? path : `/${path}`
  const location = (fileName, span) => {
    const source = service.getProgram()?.getSourceFile(fileName)
    if (!source) return null
    const pos = source.getLineAndCharacterOfPosition(span.start)
    return { path: fileName.replace(/^\//, ''), line: pos.line + 1, column: pos.character + 1, start: span.start, end: span.start + span.length }
  }
  return {
    update(path, text) {
      const key = name(path), previous = files.get(key)
      if (previous?.text === text) return
      files.set(key, { text, version: (previous?.version || 0) + 1 })
    },
    diagnostics(path) {
      return service.getSyntacticDiagnostics(name(path)).map(item => ({
        level: 'error', message: ts.flattenDiagnosticMessageText(item.messageText, '\n'),
        ...location(item.file.fileName, { start: item.start || 0, length: item.length || 0 }),
      }))
    },
    definitions(path, offset) { return (service.getDefinitionAtPosition(name(path), offset) || []).map(item => location(item.fileName, item.textSpan)).filter(Boolean) },
    references(path, offset) { return (service.getReferencesAtPosition(name(path), offset) || []).map(item => location(item.fileName, item.textSpan)).filter(Boolean) },
    dispose() { service.dispose(); files.clear() },
  }
}
