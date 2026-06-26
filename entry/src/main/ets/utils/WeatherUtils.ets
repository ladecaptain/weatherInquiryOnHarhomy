import { WEATHER_BACKGROUNDS, NIGHT_START_HOUR, NIGHT_END_HOUR } from '../constants/AppConstants'

/**
 * 天气工具函数
 * 从 weather-web/script.js 移植的纯函数，处理日期格式化、天气映射等
 */

/**
 * 格式化日期为 YYYY-MM-DD
 */
export function formatDate(date: Date): string {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

/**
 * 格式化时间字符串为 HH:mm
 */
export function formatTime(timeString: string): string {
  if (!timeString) {
    return ''
  }
  const date = new Date(timeString)
  const hours = String(date.getHours()).padStart(2, '0')
  const minutes = String(date.getMinutes()).padStart(2, '0')
  return `${hours}:${minutes}`
}

/**
 * 格式化逐小时预报时间为 "现在" / "1时" / "14时" 等
 */
export function formatHourlyTime(timeString: string): string {
  if (!timeString) {
    return ''
  }
  const now = new Date()
  const date = new Date(timeString)
  const diffMs = date.getTime() - now.getTime()
  if (diffMs <= 3600000 && diffMs >= 0) {
    return '现在'
  }
  const hours = String(date.getHours()).padStart(2, '0')
  return `${hours}:00`
}

/**
 * 根据日期字符串返回中文星期
 */
export function getDayOfWeek(dateString: string): string {
  const date = new Date(dateString)
  const days = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']
  return days[date.getDay()]
}

/**
 * 根据日期和今天/明天返回显示标签
 * @returns "今天" / "明天" / "周X"
 */
export function getDayLabel(dateString: string): string {
  const today = new Date()
  const tomorrow = new Date(today)
  tomorrow.setDate(tomorrow.getDate() + 1)

  const todayStr = formatDate(today)
  const tomorrowStr = formatDate(tomorrow)

  if (dateString === todayStr) {
    return '今天'
  }
  if (dateString === tomorrowStr) {
    return '明天'
  }
  return getDayOfWeek(dateString)
}

/**
 * 根据天气描述获取主题色
 */
export function getWeatherColor(weatherDesc: string): string {
  if (weatherDesc.includes('晴') && !weatherDesc.includes('多云')) {
    return '#e6f7ff'
  } else if (weatherDesc.includes('多云')) {
    return '#f0f0f0'
  } else if (weatherDesc.includes('阴')) {
    return '#e0e0e0'
  } else if (weatherDesc.includes('雨')) {
    return '#e6f0f5'
  } else if (weatherDesc.includes('雪')) {
    return '#f5f5f5'
  } else if (weatherDesc.includes('雾') || weatherDesc.includes('霾')) {
    return '#f0f2f5'
  } else if (weatherDesc.includes('沙尘')) {
    return '#faf3e0'
  } else if (weatherDesc.includes('雷') || weatherDesc.includes('闪电')) {
    return '#e9ecef'
  }
  return '#f0f8ff'
}

/**
 * 获取天气卡片的半透明背景色
 */
export function getWeatherCardColor(weatherDesc: string): string {
  const baseColor = getWeatherColor(weatherDesc)
  return baseColor + '33'
}

/**
 * 根据天气描述获取远程背景图 URL
 * 昼夜判断优先级：iconCode 后缀 n/d > 城市 UTC 偏移 > 设备本地时间
 */
export function getWeatherBackgroundUrl(weatherDesc: string, iconCode?: string, utcOffset?: string): string {
  const weatherType = weatherDesc.toLowerCase()
  const isNight = resolveIsNight(iconCode, utcOffset)

  if (weatherType.includes('rain') || weatherType.includes('drizzle') || weatherType.includes('雨') ||
      weatherType.includes('lluvia') || weatherType.includes('llovizna') || weatherType.includes('chubasco')) {
    return WEATHER_BACKGROUNDS.rain
  } else if ((weatherType.includes('clear') || weatherType.includes('sun') || weatherType.includes('晴') ||
              weatherType.includes('despejado') || weatherType.includes('soleado') || weatherType.includes('claro')) &&
             !weatherType.includes('cloud') && !weatherType.includes('多云') &&
             !weatherType.includes('nube') && !weatherType.includes('nublado')) {
    return isNight ? WEATHER_BACKGROUNDS.night : WEATHER_BACKGROUNDS.clear
  } else if (weatherType.includes('cloud') || weatherType.includes('overcast') ||
             weatherType.includes('多云') || weatherType.includes('阴') ||
             weatherType.includes('nublado') || weatherType.includes('nubes') || weatherType.includes('nuboso')) {
    return WEATHER_BACKGROUNDS.cloud
  } else if (weatherType.includes('snow') || weatherType.includes('雪') ||
             weatherType.includes('nieve') || weatherType.includes('nevada')) {
    return WEATHER_BACKGROUNDS.snow
  } else if (weatherType.includes('thunder') || weatherType.includes('storm') ||
             weatherType.includes('lightning') || weatherType.includes('雷') || weatherType.includes('闪电') ||
             weatherType.includes('tormenta') || weatherType.includes('trueno') || weatherType.includes('relámpago')) {
    return WEATHER_BACKGROUNDS.thunder
  } else if (weatherType.includes('fog') || weatherType.includes('mist') ||
             weatherType.includes('haze') || weatherType.includes('雾') || weatherType.includes('霾') ||
             weatherType.includes('niebla') || weatherType.includes('neblina') || weatherType.includes('bruma')) {
    return WEATHER_BACKGROUNDS.fog
  } else if (weatherType.includes('sand') || weatherType.includes('dust') ||
             weatherType.includes('沙尘') || weatherType.includes('沙') || weatherType.includes('尘') ||
             weatherType.includes('扬沙') || weatherType.includes('浮尘') ||
             weatherType.includes('arena') || weatherType.includes('polvo')) {
    return WEATHER_BACKGROUNDS.sand
  } else if (weatherType.includes('wind') || weatherType.includes('gale') || weatherType.includes('breeze') ||
             weatherType.includes('风') ||
             weatherType.includes('viento') || weatherType.includes('brisa') || weatherType.includes('ventoso')) {
    return WEATHER_BACKGROUNDS.wind
  }
  return isNight ? WEATHER_BACKGROUNDS.night : WEATHER_BACKGROUNDS.default
}

/**
 * 三级昼夜判断
 * 1. iconCode 带后缀（如 "150n"/"100d"，逐小时预报）→ 直接判断
 * 2. utcOffset 计算城市当地时间（实时天气 icon 无后缀时走此路）
 * 3. 兜底：设备本地时间
 */
function resolveIsNight(iconCode?: string, utcOffset?: string): boolean {
  if (iconCode !== undefined && (iconCode.endsWith('n') || iconCode.endsWith('d'))) {
    return iconCode.endsWith('n')
  }
  if (utcOffset !== undefined && utcOffset.length > 0) {
    return isNightAtCity(utcOffset)
  }
  return isNightTime()
}

/** 当前是否处于夜间（设备本地时间 19:00 ~ 次日 6:00） */
function isNightTime(): boolean {
  const hour = new Date().getHours()
  return hour >= NIGHT_START_HOUR || hour < NIGHT_END_HOUR
}

/**
 * 根据城市 UTC 偏移计算当地小时，判断是否为夜间
 */
function isNightAtCity(utcOffset: string): boolean {
  const match = utcOffset.match(/([+-])(\d{1,2}):(\d{2})/)
  if (!match) {
    return isNightTime()
  }
  const sign = match[1] === '-' ? -1 : 1
  const offsetHours = parseInt(match[2]) * sign
  const nowUtc = new Date()
  const utcHour = nowUtc.getUTCHours() + nowUtc.getUTCMinutes() / 60
  const cityHour = ((utcHour + offsetHours) % 24 + 24) % 24
  return cityHour >= NIGHT_START_HOUR || cityHour < NIGHT_END_HOUR
}

/**
 * 根据城市 UTC 偏移计算当地时间的格式化字符串
 * @param utcOffset 格式如 "+08:00" 或 "-05:00"
 * @returns 格式化后的当地时间，如 "14:30"
 */
export function formatCityLocalTime(utcOffset: string): string {
  if (!utcOffset || utcOffset.length === 0) {
    return formatLocalTime()
  }
  const match = utcOffset.match(/([+-])(\d{1,2}):(\d{2})/)
  if (!match) {
    return formatLocalTime()
  }
  const sign = match[1] === '-' ? -1 : 1
  const offsetHours = parseInt(match[2]) * sign
  const offsetMinutes = parseInt(match[3]) * sign

  const nowUtc = Date.now()
  const cityTime = new Date(nowUtc + offsetHours * 3600000 + offsetMinutes * 60000)

  return formatLocalTime(cityTime)
}

/** 内部工具：格式化 Date 为 HH:mm（使用 UTC 方法，避免设备本地时区二次偏移） */
function formatLocalTime(date?: Date): string {
  const d = date ?? new Date()
  const hours = String(d.getUTCHours()).padStart(2, '0')
  const minutes = String(d.getUTCMinutes()).padStart(2, '0')
  return `${hours}:${minutes}`
}

/** 默认图标，兜底使用晴天图标 */
const DEFAULT_ICON: Resource = $rawfile('weather_100.svg')

/**
 * 判断图标代码是否为降雨/雷雨类天气（300-399）
 */
export function isRainIcon(iconCode: string): boolean {
  const code = Number(iconCode.replace(/[dn]$/, ''))
  return code >= 300 && code <= 399
}

/**
 * 根据 QWeather 图标代码获取对应的图标资源
 * 使用 switch 直接返回 Resource，避免 ArkTS 编译器对 Map.set() + $rawfile() 的兼容性问题
 */
export function getWeatherIconResource(iconCode: string): Resource {
  const code = iconCode.replace(/[dn]$/, '')
  switch (code) {
    case '100':
      return $rawfile('weather_100.svg')
    case '101':
      return $rawfile('weather_101.svg')
    case '102':
      return $rawfile('weather_102.svg')
    case '103':
      return $rawfile('weather_103.svg')
    case '104':
      return $rawfile('weather_104.svg')
    case '150':
      return $rawfile('weather_150.svg')
    case '151':
      return $rawfile('weather_151.svg')
    case '152':
      return $rawfile('weather_152.svg')
    case '153':
      return $rawfile('weather_153.svg')
    case '300':
      return $rawfile('weather_300.svg')
    case '301':
      return $rawfile('weather_301.svg')
    case '302':
      return $rawfile('weather_302.svg')
    case '303':
      return $rawfile('weather_303.svg')
    case '304':
      return $rawfile('weather_304.svg')
    case '305':
      return $rawfile('weather_305.svg')
    case '306':
      return $rawfile('weather_306.svg')
    case '307':
      return $rawfile('weather_307.svg')
    case '308':
      return $rawfile('weather_308.svg')
    case '309':
      return $rawfile('weather_309.svg')
    case '310':
      return $rawfile('weather_310.svg')
    case '311':
      return $rawfile('weather_311.svg')
    case '312':
      return $rawfile('weather_312.svg')
    case '313':
      return $rawfile('weather_313.svg')
    case '314':
      return $rawfile('weather_314.svg')
    case '315':
      return $rawfile('weather_315.svg')
    case '316':
      return $rawfile('weather_316.svg')
    case '317':
      return $rawfile('weather_317.svg')
    case '318':
      return $rawfile('weather_318.svg')
    case '400':
      return $rawfile('weather_400.svg')
    case '401':
      return $rawfile('weather_401.svg')
    case '402':
      return $rawfile('weather_402.svg')
    case '403':
      return $rawfile('weather_403.svg')
    case '404':
      return $rawfile('weather_404.svg')
    case '405':
      return $rawfile('weather_405.svg')
    case '406':
      return $rawfile('weather_406.svg')
    case '407':
      return $rawfile('weather_407.svg')
    case '408':
      return $rawfile('weather_408.svg')
    case '409':
      return $rawfile('weather_409.svg')
    case '410':
      return $rawfile('weather_410.svg')
    case '500':
      return $rawfile('weather_500.svg')
    case '501':
      return $rawfile('weather_501.svg')
    case '502':
      return $rawfile('weather_502.svg')
    case '503':
      return $rawfile('weather_503.svg')
    case '504':
      return $rawfile('weather_504.svg')
    case '507':
      return $rawfile('weather_507.svg')
    case '508':
      return $rawfile('weather_508.svg')
    case '509':
      return $rawfile('weather_509.svg')
    case '510':
      return $rawfile('weather_510.svg')
    case '511':
      return $rawfile('weather_511.svg')
    case '512':
      return $rawfile('weather_512.svg')
    case '513':
      return $rawfile('weather_513.svg')
    case '514':
      return $rawfile('weather_514.svg')
    case '515':
      return $rawfile('weather_515.svg')
    case '900':
      return $rawfile('weather_900.svg')
    case '901':
      return $rawfile('weather_901.svg')
    default:
      return DEFAULT_ICON
  }
}
