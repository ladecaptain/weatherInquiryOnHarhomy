/**
 * 应用常量定义
 * QWeather API 配置和应用级常量
 */

// QWeather API 密钥（免费订阅）
export const API_KEY = 'a8482d925cc44a749e9d77a8114c5f79'

// QWeather API 基础地址
export const API_BASE = 'https://mt63yw2ku6.re.qweatherapi.com'

// 城市查找 API
export const CITY_LOOKUP_URL = `${API_BASE}/geo/v2/city/lookup`

// 实时天气 API
export const CURRENT_WEATHER_URL = `${API_BASE}/v7/weather/now`

// 7天预报 API
export const FORECAST_URL = `${API_BASE}/v7/weather/7d`

// 逐小时预报 API（24小时）
export const HOURLY_FORECAST_URL = `${API_BASE}/v7/weather/24h`

// 15天预报 API
export const FORECAST_15D_URL = `${API_BASE}/v7/weather/15d`

// 空气质量 API
export const AIR_QUALITY_URL = `${API_BASE}/v7/air/now`

/** 天气背景图片 CDN 地址映射接口 */
export interface WeatherBackgroundsMap {
  rain: string
  clear: string
  cloud: string
  snow: string
  thunder: string
  fog: string
  sand: string
  wind: string
  night: string
  default: string
}

// 天气背景图片 CDN 地址映射
export const WEATHER_BACKGROUNDS: WeatherBackgroundsMap = {
  rain: 'https://img.cdn1.vip/i/6a3ce3b177d2f_1782375345.webp',
  clear: 'https://img.cdn1.vip/i/6a13f32673ca8_1779692326.webp',
  cloud: 'https://img.cdn1.vip/i/6a13f325c706a_1779692325.webp',
  snow: 'https://img.cdn1.vip/i/6a3ce0057b275_1782374405.webp',
  thunder: 'https://img.cdn1.vip/i/6a13f3259ddda_1779692325.webp',
  fog: 'https://img.cdn1.vip/i/6a13f326a1fb1_1779692326.jpg',
  sand: 'https://img.cdn1.vip/i/6a3ce3b039e73_1782375344.webp',
  wind: 'https://img.cdn1.vip/i/6a3ce3b228e40_1782375346.webp',
  night: 'https://img.cdn1.vip/i/6a3ce06f2cd68_1782374511.jpg',
  default: 'https://tc.z.wiki/autoupload/f/I52rW2iUJFZLBJDpySwU0Kafo_6-hTJekmBMO9zizzGyl5f0KlZfm6UsKj-HyTuv/20250910/TgXm/1920X1080/sunny.jpg'
}

/** 夜间开始时间（小时） */
export const NIGHT_START_HOUR = 19

/** 夜间结束时间（小时） */
export const NIGHT_END_HOUR = 6
