import { geoLocationManager } from '@kit.LocationKit'
import { abilityAccessCtrl, Permissions, bundleManager } from '@kit.AbilityKit'

/**
 * 定位服务封装
 * 处理权限申请、位置服务开关检查、获取当前设备坐标、持续定位监听
 */

/** 定位结果 */
export interface LocationResult {
  latitude: number
  longitude: number
}

/** 默认位置（北京），定位失败时兜底 */
const DEFAULT_LOCATION: LocationResult = {
  latitude: 39.904,
  longitude: 116.405
}

/** 触发城市更新的最小移动距离（米），约5公里 */
const LOCATION_CHANGE_THRESHOLD_METERS = 5000

/** 防抖间隔（毫秒），避免频繁触发天气查询 */
const DEBOUNCE_INTERVAL_MS = 30000

/**
 * 静默检查定位权限（不弹窗）
 * @returns 是否已授权
 */
export function hasLocationPermission(): boolean {
  const atManager = abilityAccessCtrl.createAtManager()
  try {
    const bundleInfo = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
    const tokenId = bundleInfo.appInfo.accessTokenId
    const permissions: Array<Permissions> = [
      'ohos.permission.APPROXIMATELY_LOCATION',
      'ohos.permission.LOCATION'
    ]
    return permissions.every((perm: Permissions) => {
      const result = atManager.verifyAccessTokenSync(tokenId, perm)
      return result === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED
    })
  } catch {
    return false
  }
}

/**
 * 请求定位权限并向用户申请授权
 * @returns 是否已获得授权
 */
async function requestPermission(context: Context): Promise<boolean> {
  const atManager = abilityAccessCtrl.createAtManager()
  const permissions: Array<Permissions> = [
    'ohos.permission.APPROXIMATELY_LOCATION',
    'ohos.permission.LOCATION'
  ]
  try {
    const result = await atManager.requestPermissionsFromUser(context, permissions)
    // authResults 中 0 表示授权，-1 表示拒绝
    return result.authResults.every((r: number) => r === 0)
  } catch {
    return false
  }
}

/**
 * 获取当前设备坐标
 * 依次完成：权限检查 → 位置开关检查 → 获取定位
 * @returns LocationResult，失败时返回默认值（北京）
 */
export async function getDeviceLocation(context: Context): Promise<LocationResult> {
  // 1. 申请权限
  const hasPermission = await requestPermission(context)
  if (!hasPermission) {
    console.warn('[LocationService] 定位权限未授予，使用默认位置')
    return DEFAULT_LOCATION
  }

  // 2. 检查位置服务是否开启
  try {
    if (!geoLocationManager.isLocationEnabled()) {
      console.warn('[LocationService] 位置服务未开启，使用默认位置')
      return DEFAULT_LOCATION
    }
  } catch {
    console.warn('[LocationService] 检查位置服务失败，使用默认位置')
    return DEFAULT_LOCATION
  }

  // 3. 获取当前位置
  try {
    const request: geoLocationManager.SingleLocationRequest = {
      locatingPriority: geoLocationManager.LocatingPriority.PRIORITY_LOCATING_SPEED,
      locatingTimeoutMs: 10000
    }
    const location = await geoLocationManager.getCurrentLocation(request)
    return {
      latitude: location.latitude,
      longitude: location.longitude
    }
  } catch (error) {
    console.warn(`[LocationService] 定位失败: ${JSON.stringify(error)}，使用默认位置`)
    return DEFAULT_LOCATION
  }
}

// ─── 持续定位 ────────────────────────────────────────────

/** 上次通知外部的坐标，用于判断是否发生显著移动 */
let lastNotifiedLocation: LocationResult | null = null

/** 防抖定时器ID */
let debounceTimer: number | null = null

/** 外部回调引用，用于 offLocationChange */
let locationChangeCallback: ((location: geoLocationManager.Location) => void) | null = null

/**
 * 启动持续定位监听
 * 当设备移动超过阈值距离时，通过 onLocationChanged 回调通知外部
 * @param onLocationChanged 位置变化时的回调（已通过防抖和距离阈值过滤）
 */
export function startContinuousLocation(
  onLocationChanged: (location: LocationResult) => void
): void {
  if (locationChangeCallback) {
    console.info('[LocationService] 持续定位已在监听中，先停止再重新启动')
    stopContinuousLocation()
  }

  if (!hasLocationPermission()) {
    console.warn('[LocationService] 无定位权限，无法启动持续定位')
    return
  }

  const request: geoLocationManager.LocationRequest = {
    priority: geoLocationManager.LocationRequestPriority.LOW_POWER,
    scenario: geoLocationManager.LocationRequestScenario.DAILY_LIFE_SERVICE,
    timeInterval: 5,
    distanceInterval: 0
  }

  locationChangeCallback = (location: geoLocationManager.Location): void => {
    const newLocation: LocationResult = {
      latitude: location.latitude,
      longitude: location.longitude
    }

    // 首次上报
    if (!lastNotifiedLocation) {
      lastNotifiedLocation = newLocation
    }

    // 计算与上次通知位置的距离
    const distance = haversineDistance(lastNotifiedLocation, newLocation)
    if (distance < LOCATION_CHANGE_THRESHOLD_METERS) {
      return
    }

    // 防抖：清除之前的定时器，重新计时
    if (debounceTimer !== null) {
      clearTimeout(debounceTimer)
    }

    debounceTimer = setTimeout(() => {
      console.info(`[LocationService] 位置显著变化 (${distance.toFixed(0)}m)，通知外部`)
      lastNotifiedLocation = newLocation
      onLocationChanged(newLocation)
      debounceTimer = null
    }, DEBOUNCE_INTERVAL_MS)
  }

  try {
    geoLocationManager.on('locationChange', request, locationChangeCallback)
    console.info('[LocationService] 持续定位监听已启动')
  } catch (err) {
    console.error(`[LocationService] 启动持续定位失败: ${JSON.stringify(err)}`)
  }
}

/**
 * 停止持续定位监听
 */
export function stopContinuousLocation(): void {
  if (locationChangeCallback) {
    try {
      geoLocationManager.off('locationChange', locationChangeCallback)
      console.info('[LocationService] 持续定位监听已停止')
    } catch (err) {
      console.error(`[LocationService] 停止持续定位失败: ${JSON.stringify(err)}`)
    }
    locationChangeCallback = null
  }

  lastNotifiedLocation = null
  if (debounceTimer !== null) {
    clearTimeout(debounceTimer)
    debounceTimer = null
  }
}

/**
 * 使用 Haversine 公式计算两点间球面距离（米）
 */
function haversineDistance(a: LocationResult, b: LocationResult): number {
  const R = 6371000 // 地球半径（米）
  const toRad = (deg: number): number => deg * Math.PI / 180

  const dLat = toRad(b.latitude - a.latitude)
  const dLon = toRad(b.longitude - a.longitude)
  const lat1 = toRad(a.latitude)
  const lat2 = toRad(b.latitude)

  const aVal = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2
  const c = 2 * Math.atan2(Math.sqrt(aVal), Math.sqrt(1 - aVal))

  return R * c
}
