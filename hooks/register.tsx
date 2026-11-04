import type { EngineInterface, Register, SessionRateLimit } from 'claude-code'

const REFRESH_MS = 30_000

// Widget chỉ có trên Windows; nơi không có USERPROFILE thì mod không làm gì.
const outFile = async ($: EngineInterface) => {
  const home = await $.env.get('USERPROFILE')

  return home ? `${home}/.claude/token-meter.json` : undefined
}

const save = async ($: EngineInterface, limits: SessionRateLimit[]) => {
  const out = await outFile($)

  if (out && limits.length > 0) {
    await $.fs.write(out, JSON.stringify({ updatedAt: new Date().toISOString(), limits }))
  }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const started = await next(e)

    if (!(await outFile($))) {
      return started
    }

    const refresh = async () => save($, (await $.session.usage()).rateLimits)

    await refresh()
    $.clock.every(REFRESH_MS, () => void refresh())

    const widget = `${$.plugin.root}/widget/float.ps1`.replaceAll("'", "''")
    await $.process.run([
      'powershell.exe',
      '-NoProfile',
      '-Command',
      `Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile','-STA','-ExecutionPolicy','Bypass','-File','"${widget}"'`,
    ])

    return started
  })

  on('session.measure', async ($, e, next) => {
    await save($, e.rateLimits)

    return next(e)
  })
}
