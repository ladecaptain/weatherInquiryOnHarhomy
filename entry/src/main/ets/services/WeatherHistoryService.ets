import { preferences } from '@kit.ArkData'
import { ForecastDay, HourlyForecastItem } from '../model/WeatherModel'

interface DailySnapshot {
  date: string
  forecastDay: ForecastDay
  hourlyData: HourlyForecastItem[]
}

const STORE_NAME = 'weather_history'

async function getStore(context: Context): Promise<preferences.Preferences> {
  return preferences.getPreferences(context, STORE_NAME)
}

function getKey(cityId: string): string {
  return `hist_${cityId}`
}

function formatDate(date: Date): string {
  const y = date.getFullYear()
  const m = String(date.getMonth() + 1).padStart(2, '0')
  const d = String(date.getDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}

export async function saveTodaySnapshot(
  context: Context,
  cityId: string,
  forecastDay: ForecastDay,
  hourlyData: HourlyForecastItem[]
): Promise<void> {
  const today = formatDate(new Date())
  const store = await getStore(context)
  const key = getKey(cityId)

  const raw = store.getSync(key, '[]') as string
  const list: DailySnapshot[] = JSON.parse(raw)

  const yesterday = formatDate(new Date(Date.now() - 86400000))
  const filtered: DailySnapshot[] = []
  for (const s of list) {
    if (s.date === today || s.date === yesterday) {
      filtered.push(s)
    }
  }

  const existing = filtered.findIndex(s => s.date === today)
  const snapshot: DailySnapshot = { date: today, forecastDay, hourlyData }
  if (existing >= 0) {
    filtered[existing] = snapshot
  } else {
    filtered.unshift(snapshot)
  }

  store.putSync(key, JSON.stringify(filtered))
  store.flush()
}

export async function loadYesterdaySnapshot(
  context: Context,
  cityId: string
): Promise<DailySnapshot | null> {
  const yesterday = formatDate(new Date(Date.now() - 86400000))
  const store = await getStore(context)
  const key = getKey(cityId)

  const raw = store.getSync(key, '[]') as string
  const list: DailySnapshot[] = JSON.parse(raw)

  for (const s of list) {
    if (s.date === yesterday) {
      return s
    }
  }
  return null
}
