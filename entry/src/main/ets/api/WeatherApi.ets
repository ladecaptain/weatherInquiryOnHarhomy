import { http } from '@kit.NetworkKit'
import { API_KEY, CITY_LOOKUP_URL, CURRENT_WEATHER_URL, FORECAST_URL, HOURLY_FORECAST_URL, AIR_QUALITY_URL, FORECAST_15D_URL, WEATHER_WARNING_URL } from '../constants/AppConstants'
import { CityLocation, CurrentWeatherData, ForecastDay, HourlyForecastItem, CityLookupResponse, NowWeatherResponse, ForecastResponse, HourlyForecastResponse, AirQualityData, AirQualityResponse, Forecast15DResponse, WarningItem, WarningResponse } from '../model/WeatherModel'

/**
 * QWeather API 网络请求层
 */

/**
 * 通用 GET 请求 → JSON 对象
 */
async function apiGet<T>(url: string): Promise<T> {
  const httpRequest = http.createHttp()
  try {
    const response: http.HttpResponse = await httpRequest.request(url, {
      method: http.RequestMethod.GET,
      header: {
        'Accept': 'application/json',
        'Accept-Encoding': 'identity'
      },
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 10000,
      readTimeout: 10000
    })

    if (response.responseCode !== 200) {
      throw new Error(`网络请求失败 (HTTP ${response.responseCode})`)
    }

    const raw: string = response.result as string
    const parsed: Record<string, Object> = JSON.parse(raw) as Record<string, Object>

    if (parsed.code && parsed.code !== '200') {
      const errorMessages: Record<string, string> = {
        '401': 'API 密钥无效或已过期，请联系管理员。',
        '402': 'API 调用次数已超过配额。',
        '403': '无权限访问该 API。',
        '404': '请求的资源不存在。',
        '429': '请求过于频繁，请稍后重试。',
        '500': '服务器内部错误，请稍后重试。'
      }
      const apiCode = parsed.code as string
      const msg = errorMessages[apiCode] || `API 错误 (code: ${apiCode})`
      throw new Error(msg)
    }

    return parsed as T
  } catch (error) {
    if (error instanceof Error) {
      throw error
    }
    throw new Error('网络连接失败，请检查网络设置后重试。')
  } finally {
    httpRequest.destroy()
  }
}

// ─── 公开 API ────────────────────────────────────────────

export async function cityLookup(cityName: string): Promise<CityLocation> {
  const url = `${CITY_LOOKUP_URL}?location=${encodeURIComponent(cityName)}&key=${API_KEY}&lang=zh`
  const data = await apiGet<CityLookupResponse>(url)
  if (data.code !== '200' || !data.location || data.location.length === 0) {
    throw new Error('找不到该城市，请检查输入是否正确。')
  }
  return {
    name: data.location[0].name, id: data.location[0].id,
    lat: data.location[0].lat, lon: data.location[0].lon,
    adm2: data.location[0].adm2, adm1: data.location[0].adm1,
    country: data.location[0].country,
    tz: data.location[0].tz ?? '', utcOffset: data.location[0].utcOffset ?? '',
    isDst: data.location[0].isDst ?? '', type: '', rank: '', fxLink: ''
  }
}

/** 城市查找（多结果），返回全部匹配 */
export async function cityLookupAll(cityName: string): Promise<CityLocation[]> {
  const url = `${CITY_LOOKUP_URL}?location=${encodeURIComponent(cityName)}&key=${API_KEY}&lang=zh`
  const data = await apiGet<CityLookupResponse>(url)
  if (data.code !== '200' || !data.location || data.location.length === 0) {
    throw new Error('找不到该城市，请检查输入是否正确。')
  }
  const result: CityLocation[] = []
  for (let i = 0; i < data.location.length; i++) {
    const loc = data.location[i]
    result.push({
      name: loc.name, id: loc.id,
      lat: loc.lat, lon: loc.lon,
      adm2: loc.adm2, adm1: loc.adm1,
      country: loc.country,
      tz: loc.tz ?? '', utcOffset: loc.utcOffset ?? '', isDst: loc.isDst ?? '', type: '', rank: '', fxLink: ''
    })
  }
  return result
}

export async function getCurrentWeather(locationId: string): Promise<CurrentWeatherData> {
  const url = `${CURRENT_WEATHER_URL}?location=${locationId}&key=${API_KEY}&lang=zh`
  const data = await apiGet<NowWeatherResponse>(url)
  if (data.code !== '200' || !data.now) {
    throw new Error('获取实时天气信息失败。')
  }
  return data.now
}

export async function getForecast(locationId: string): Promise<ForecastDay[]> {
  const url = `${FORECAST_URL}?location=${locationId}&key=${API_KEY}&lang=zh`
  const data = await apiGet<ForecastResponse>(url)
  if (data.code !== '200' || !data.daily || data.daily.length === 0) {
    throw new Error('获取天气预报信息失败。')
  }
  return data.daily
}

export async function getHourlyForecast(locationId: string): Promise<HourlyForecastItem[]> {
  const url = `${HOURLY_FORECAST_URL}?location=${locationId}&key=${API_KEY}&lang=zh`
  const data = await apiGet<HourlyForecastResponse>(url)
  if (data.code !== '200' || !data.hourly || data.hourly.length === 0) {
    throw new Error('获取逐小时预报失败。')
  }
  return data.hourly
}

export async function getAirQuality(locationId: string): Promise<AirQualityData> {
  const url = `${AIR_QUALITY_URL}?location=${locationId}&key=${API_KEY}&lang=zh`
  const data = await apiGet<AirQualityResponse>(url)
  if (data.code !== '200' || !data.now) {
    throw new Error('获取空气质量数据失败。')
  }
  return data.now
}

/** 获取 15 天天气预报 */
export async function getForecast15D(locationId: string): Promise<ForecastDay[]> {
  const url = `${FORECAST_15D_URL}?location=${locationId}&key=${API_KEY}&lang=zh`
  const data = await apiGet<Forecast15DResponse>(url)
  if (data.code !== '200' || !data.daily || data.daily.length === 0) {
    throw new Error('获取15天天气预报失败。')
  }
  return data.daily
}

/** 获取天气预警 */
export async function getWeatherWarning(locationId: string): Promise<WarningItem[]> {
  const url = `${WEATHER_WARNING_URL}?location=${locationId}&key=${API_KEY}&lang=zh`
  const data = await apiGet<WarningResponse>(url)
  if (data.code !== '200') {
    throw new Error('获取天气预警失败。')
  }
  return data.warning ?? []
}
