import { preferences } from '@kit.ArkData'

/** 收藏城市数据结构 */
export interface FavoriteCity {
  name: string    // 城市名，如"北京"
  id: string      // QWeather locationId
  adm1: string    // 省份
  adm2: string    // 区县
  lat: string
  lon: string
  utcOffset?: string // UTC 偏移（如 "-04:00"），用于判断当地昼夜
}

const STORE_NAME = 'weather_favorites'
const KEY_FAVORITES = 'city_list'

/** 从 Preferences 读取收藏列表 */
async function getStore(context: Context): Promise<preferences.Preferences> {
  return preferences.getPreferences(context, STORE_NAME)
}

/** 获取所有收藏城市 */
export async function getFavorites(context: Context): Promise<FavoriteCity[]> {
  const store = await getStore(context)
  const json = store.getSync(KEY_FAVORITES, '[]') as string
  return JSON.parse(json)
}

/** 添加收藏（已存在则跳过） */
export async function addFavorite(context: Context, city: FavoriteCity): Promise<void> {
  const store = await getStore(context)
  const list = await getFavorites(context)
  if (list.some(c => c.id === city.id)) {
    return // 已存在则跳过
  }
  list.unshift(city)
  store.putSync(KEY_FAVORITES, JSON.stringify(list))
  store.flush()
}

/** 移除收藏 */
export async function removeFavorite(context: Context, cityId: string): Promise<void> {
  const store = await getStore(context)
  const list = await getFavorites(context)
  const filtered = list.filter(c => c.id !== cityId)
  store.putSync(KEY_FAVORITES, JSON.stringify(filtered))
  store.flush()
}

/** 判断是否已收藏 */
export async function isFavorite(context: Context, cityId: string): Promise<boolean> {
  const list = await getFavorites(context)
  return list.some(c => c.id === cityId)
}
