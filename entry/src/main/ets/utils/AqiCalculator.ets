/**
 * AQI 空气质量指数计算工具
 * 基于 HJ 633-2012 环境空气质量指数(AQI)技术规定
 * 当 API 未直接提供 AQI 时，从单项污染物浓度推算
 */

/** AQI 计算结果 */
export interface AqiResult {
  aqi: number
  category: string
  primaryPollutant: string
}

/** 污染物浓度断点 → IAQI 映射 */
interface Breakpoint {
  bpLo: number
  bpHi: number
  iaqiLo: number
  iaqiHi: number
}

/** 污染物断点总表 */
interface PollutantBreakpoints {
  pm25: Breakpoint[]
  pm10: Breakpoint[]
  so2: Breakpoint[]
  no2: Breakpoint[]
  co: Breakpoint[]
  o3: Breakpoint[]
}

/** 中国 AQI 分级标准 (HJ 633-2012) */
const AQI_BREAKPOINTS: PollutantBreakpoints = {
  pm25: [
    { bpLo: 0, bpHi: 35, iaqiLo: 0, iaqiHi: 50 },
    { bpLo: 35, bpHi: 75, iaqiLo: 50, iaqiHi: 100 },
    { bpLo: 75, bpHi: 115, iaqiLo: 100, iaqiHi: 150 },
    { bpLo: 115, bpHi: 150, iaqiLo: 150, iaqiHi: 200 },
    { bpLo: 150, bpHi: 250, iaqiLo: 200, iaqiHi: 300 },
    { bpLo: 250, bpHi: 350, iaqiLo: 300, iaqiHi: 400 },
    { bpLo: 350, bpHi: 500, iaqiLo: 400, iaqiHi: 500 }
  ],
  pm10: [
    { bpLo: 0, bpHi: 50, iaqiLo: 0, iaqiHi: 50 },
    { bpLo: 50, bpHi: 150, iaqiLo: 50, iaqiHi: 100 },
    { bpLo: 150, bpHi: 250, iaqiLo: 100, iaqiHi: 150 },
    { bpLo: 250, bpHi: 350, iaqiLo: 150, iaqiHi: 200 },
    { bpLo: 350, bpHi: 420, iaqiLo: 200, iaqiHi: 300 },
    { bpLo: 420, bpHi: 500, iaqiLo: 300, iaqiHi: 400 },
    { bpLo: 500, bpHi: 600, iaqiLo: 400, iaqiHi: 500 }
  ],
  so2: [
    { bpLo: 0, bpHi: 150, iaqiLo: 0, iaqiHi: 50 },
    { bpLo: 150, bpHi: 500, iaqiLo: 50, iaqiHi: 100 },
    { bpLo: 500, bpHi: 650, iaqiLo: 100, iaqiHi: 150 },
    { bpLo: 650, bpHi: 800, iaqiLo: 150, iaqiHi: 200 },
    { bpLo: 800, bpHi: 1600, iaqiLo: 200, iaqiHi: 300 },
    { bpLo: 1600, bpHi: 2100, iaqiLo: 300, iaqiHi: 400 },
    { bpLo: 2100, bpHi: 2620, iaqiLo: 400, iaqiHi: 500 }
  ],
  no2: [
    { bpLo: 0, bpHi: 100, iaqiLo: 0, iaqiHi: 50 },
    { bpLo: 100, bpHi: 200, iaqiLo: 50, iaqiHi: 100 },
    { bpLo: 200, bpHi: 700, iaqiLo: 100, iaqiHi: 150 },
    { bpLo: 700, bpHi: 1200, iaqiLo: 150, iaqiHi: 200 },
    { bpLo: 1200, bpHi: 2340, iaqiLo: 200, iaqiHi: 300 },
    { bpLo: 2340, bpHi: 3090, iaqiLo: 300, iaqiHi: 400 },
    { bpLo: 3090, bpHi: 3840, iaqiLo: 400, iaqiHi: 500 }
  ],
  co: [
    { bpLo: 0, bpHi: 5, iaqiLo: 0, iaqiHi: 50 },
    { bpLo: 5, bpHi: 10, iaqiLo: 50, iaqiHi: 100 },
    { bpLo: 10, bpHi: 35, iaqiLo: 100, iaqiHi: 150 },
    { bpLo: 35, bpHi: 60, iaqiLo: 150, iaqiHi: 200 },
    { bpLo: 60, bpHi: 90, iaqiLo: 200, iaqiHi: 300 },
    { bpLo: 90, bpHi: 120, iaqiLo: 300, iaqiHi: 400 },
    { bpLo: 120, bpHi: 150, iaqiLo: 400, iaqiHi: 500 }
  ],
  o3: [
    { bpLo: 0, bpHi: 160, iaqiLo: 0, iaqiHi: 50 },
    { bpLo: 160, bpHi: 200, iaqiLo: 50, iaqiHi: 100 },
    { bpLo: 200, bpHi: 300, iaqiLo: 100, iaqiHi: 150 },
    { bpLo: 300, bpHi: 400, iaqiLo: 150, iaqiHi: 200 },
    { bpLo: 400, bpHi: 800, iaqiLo: 200, iaqiHi: 300 },
    { bpLo: 800, bpHi: 1000, iaqiLo: 300, iaqiHi: 400 },
    { bpLo: 1000, bpHi: 1200, iaqiLo: 400, iaqiHi: 500 }
  ]
}

/** 污染物中文名 */
function getPollutantName(key: string): string {
  const names: string[] = ['pm25', 'pm10', 'so2', 'no2', 'co', 'o3']
  const labels: string[] = ['PM2.5', 'PM10', 'SO₂', 'NO₂', 'CO', 'O₃']
  for (let i = 0; i < names.length; i++) {
    if (names[i] === key) return labels[i]
  }
  return key
}

/**
 * 计算单个污染物的 IAQI
 * 公式: IAQI = (IAQI_hi - IAQI_lo) / (BP_hi - BP_lo) × (C - BP_lo) + IAQI_lo
 */
function calcIaqi(concentration: number, breakpoints: Breakpoint[]): number {
  if (isNaN(concentration) || concentration < 0) {
    return 0
  }

  for (let i = 0; i < breakpoints.length; i++) {
    const bp = breakpoints[i]
    if (concentration >= bp.bpLo && concentration <= bp.bpHi) {
      if (bp.bpHi === bp.bpLo) {
        return bp.iaqiLo
      }
      const iaqi = ((bp.iaqiHi - bp.iaqiLo) / (bp.bpHi - bp.bpLo)) *
        (concentration - bp.bpLo) + bp.iaqiLo
      return Math.round(iaqi)
    }
  }

  // 超出最大断点 → 取上限
  const last = breakpoints[breakpoints.length - 1]
  return last.iaqiHi
}

/** 根据 AQI 获取等级名称 */
function getCategory(aqi: number): string {
  if (aqi <= 50) return '优'
  if (aqi <= 100) return '良'
  if (aqi <= 150) return '轻度污染'
  if (aqi <= 200) return '中度污染'
  if (aqi <= 300) return '重度污染'
  return '严重污染'
}

/**
 * 综合计算 AQI
 */
export function calculateAqi(
  pm25: string | number,
  pm10: string | number,
  so2: string | number,
  no2: string | number,
  co: string | number,
  o3: string | number
): AqiResult {
  const c_pm25 = typeof pm25 === 'string' ? parseFloat(pm25) : pm25
  const c_pm10 = typeof pm10 === 'string' ? parseFloat(pm10) : pm10
  const c_so2 = typeof so2 === 'string' ? parseFloat(so2) : so2
  const c_no2 = typeof no2 === 'string' ? parseFloat(no2) : no2
  const c_co = typeof co === 'string' ? parseFloat(co) : co
  const c_o3 = typeof o3 === 'string' ? parseFloat(o3) : o3

  const iaqi_pm25 = calcIaqi(c_pm25, AQI_BREAKPOINTS.pm25)
  const iaqi_pm10 = calcIaqi(c_pm10, AQI_BREAKPOINTS.pm10)
  const iaqi_so2 = calcIaqi(c_so2, AQI_BREAKPOINTS.so2)
  const iaqi_no2 = calcIaqi(c_no2, AQI_BREAKPOINTS.no2)
  const iaqi_co = calcIaqi(c_co, AQI_BREAKPOINTS.co)
  const iaqi_o3 = calcIaqi(c_o3, AQI_BREAKPOINTS.o3)

  const iaqiAll: IAQIEntry[] = [
    { key: 'pm25', value: iaqi_pm25 },
    { key: 'pm10', value: iaqi_pm10 },
    { key: 'so2', value: iaqi_so2 },
    { key: 'no2', value: iaqi_no2 },
    { key: 'co', value: iaqi_co },
    { key: 'o3', value: iaqi_o3 }
  ]

  let maxIaqi = 0
  let primaryPollutant = ''
  for (let i = 0; i < iaqiAll.length; i++) {
    if (iaqiAll[i].value > maxIaqi) {
      maxIaqi = iaqiAll[i].value
      primaryPollutant = iaqiAll[i].key
    }
  }

  return {
    aqi: maxIaqi,
    category: getCategory(maxIaqi),
    primaryPollutant: getPollutantName(primaryPollutant)
  }
}

/** IAQI 单项值 */
interface IAQIEntry {
  key: string
  value: number
}
