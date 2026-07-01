import { preferences } from '@kit.ArkData'
import { PREF_TEMP_UNIT } from '../constants/AppConstants'

/** AppStorage 键 — 存储 '°C' 或 '°F' */
const TEMP_UNIT_KEY = 'tempUnit'

/**
 * 温度单位服务
 * 使用 AppStorage 实现全局响应式：任意处调用 setUnit() 后所有绑定组件自动刷新。
 */
export class TemperatureService {
  private static instance: TemperatureService

  static getInstance(): TemperatureService {
    if (!TemperatureService.instance) {
      TemperatureService.instance = new TemperatureService()
    }
    return TemperatureService.instance
  }

  /** 从 Preferences 加载存储的单位并写入 AppStorage（响应式根） */
  async init(context: Context): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(context, 'weather_settings')
      const saved = prefs.getSync(PREF_TEMP_UNIT, 'CELSIUS') as string
      const unit = saved === 'FAHRENHEIT' ? '°F' : '°C'
      AppStorage.setOrCreate<string>(TEMP_UNIT_KEY, unit)
    } catch {
      AppStorage.setOrCreate<string>(TEMP_UNIT_KEY, '°C')
    }
  }

  /** 获取当前单位（直接从 AppStorage 读取） */
  getUnit(): string {
    const val = AppStorage.get<string>(TEMP_UNIT_KEY)
    return val || '°C'
  }

  /** 切换 °C ↔ °F 并持久化 */
  async toggleUnit(context: Context): Promise<void> {
    const current = this.getUnit()
    const next = current === '°C' ? '°F' : '°C'
    AppStorage.set<string>(TEMP_UNIT_KEY, next) // 触发所有 @StorageLink / @StorageProp 刷新
    await this.persistUnit(context, next)
  }

  /** 直接设置指定单位并持久化 */
  async setUnit(context: Context, unit: string): Promise<void> {
    if (unit !== '°C' && unit !== '°F') {
      return
    }
    AppStorage.set<string>(TEMP_UNIT_KEY, unit)
    await this.persistUnit(context, unit)
  }

  /** 持久化到 Preferences */
  private async persistUnit(context: Context, unit: string): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(context, 'weather_settings')
      await prefs.put(PREF_TEMP_UNIT, unit === '°F' ? 'FAHRENHEIT' : 'CELSIUS')
      await prefs.flush()
    } catch {
      // 静默失败
    }
  }

  /** 格式化温度：根据指定单位转换（未传则从 AppStorage 读取） */
  formatTemp(celsiusStr: string, unit?: string): string {
    const celsius = parseFloat(celsiusStr)
    if (isNaN(celsius)) {
      return '--'
    }
    const u = unit || this.getUnit()
    if (u === '°C') {
      return `${Math.round(celsius)}`
    }
    const fahrenheit = celsius * 9 / 5 + 32
    return `${Math.round(fahrenheit)}`
  }

  /** 获取单位符号 */
  getUnitSymbol(): string {
    return this.getUnit()
  }
}

/** 获取单例快捷方式 */
export function tempService(): TemperatureService {
  return TemperatureService.getInstance()
}

/** 便捷格式化：celsius 字符串 → 带单位的显示字符串，如 "25°C"（可选传入 unit 以建立 ArkTS 依赖） */
export function formatTempWithUnit(celsiusStr: string, unit?: string): string {
  const value = tempService().formatTemp(celsiusStr, unit)
  return `${value}${unit || tempService().getUnitSymbol()}`
}
