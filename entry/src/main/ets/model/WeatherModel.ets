/**
 * 天气数据模型
 * 对应 QWeather API 返回的 JSON 结构
 */

/** API 数据来源引用 */
export interface WeatherRefer {
  sources: string[]
  license: string[]
}

/** QWeather API 通用响应包装 */
export interface WeatherResponse<T> {
  code: string
  updateTime: string
  fxLink?: string
  now?: T
  daily?: T[]
  location?: CityLocation[]
  refer?: WeatherRefer
}

/** 城市搜索返回的城市信息 */
export interface CityLocation {
  name: string
  id: string
  lat: string
  lon: string
  adm2: string
  adm1: string
  country: string
  tz: string
  utcOffset: string
  isDst: string
  type: string
  rank: string
  fxLink: string
}

/** 实时天气数据 */
export interface CurrentWeatherData {
  obsTime: string
  temp: string
  feelsLike: string
  icon: string
  text: string
  wind360: string
  windDir: string
  windScale: string
  windSpeed: string
  humidity: string
  precip: string
  pressure: string
  vis: string
  cloud: string
  dew: string
}

/** 单日天气预报 */
export interface ForecastDay {
  fxDate: string
  sunrise: string
  sunset: string
  moonrise: string
  moonset: string
  moonPhase: string
  moonPhaseIcon: string
  tempMax: string
  tempMin: string
  iconDay: string
  textDay: string
  iconNight: string
  textNight: string
  wind360Day: string
  windDirDay: string
  windScaleDay: string
  windSpeedDay: string
  wind360Night: string
  windDirNight: string
  windScaleNight: string
  windSpeedNight: string
  humidity: string
  precip: string
  pressure: string
  vis: string
  cloud: string
  uvIndex: string
}

/** 城市查找简要信息（API 响应用） */
export interface CityLocationBrief {
  name: string
  id: string
  lat: string
  lon: string
  adm2: string
  adm1: string
  country: string
  tz?: string
  utcOffset?: string
  isDst?: string
}

/** 城市查找 API 响应 */
export interface CityLookupResponse {
  code: string
  location: CityLocationBrief[]
}

/** 实时天气 API 响应 */
export interface NowWeatherResponse {
  code: string
  updateTime: string
  now: CurrentWeatherData
}

/** 预报天气 API 响应 */
export interface ForecastResponse {
  code: string
  updateTime: string
  daily: ForecastDay[]
}

/** 逐小时预报数据 */
export interface HourlyForecastItem {
  fxTime: string
  temp: string
  icon: string
  text: string
  wind360: string
  windDir: string
  windScale: string
  windSpeed: string
  humidity: string
  pop: string
  precip: string
  pressure: string
  cloud: string
  dew: string
}

/** 逐小时预报 API 响应 */
export interface HourlyForecastResponse {
  code: string
  updateTime: string
  hourly: HourlyForecastItem[]
}

/** 15 天预报 API 响应（结构同 7 天） */
export interface Forecast15DResponse {
  code: string
  updateTime: string
  daily: ForecastDay[]
}

/** 空气质量数据 */
export interface AirQualityData {
  pubTime: string
  aqi: string
  level: string
  category: string
  primary: string
  pm10: string
  pm2p5: string
  no2: string
  so2: string
  co: string
  o3: string
}

/** 空气质量 API 响应 */
export interface AirQualityResponse {
  code: string
  updateTime: string
  now: AirQualityData
}
