import { CurrentWeatherData, ForecastDay, HourlyForecastItem, AirQualityData, WarningItem } from '../model/WeatherModel'
import { cityLookup, getCurrentWeather, getForecast, getHourlyForecast, getAirQuality, getForecast15D, getWeatherWarning } from '../api/WeatherApi'
import { getWeatherBackgroundUrl, isClearWeatherBackground } from '../utils/WeatherUtils'
import { getDeviceLocation, startContinuousLocation, stopContinuousLocation, LocationResult } from '../services/LocationService'
import { getFavorites, FavoriteCity } from '../services/FavoriteCityManager'
import { TemperatureService, formatTempWithUnit } from '../services/TemperatureService'
import { saveTodaySnapshot, loadYesterdaySnapshot } from '../services/WeatherHistoryService'
import { CurrentWeatherCard } from '../components/CurrentWeatherCard'
import { HourlyForecast } from '../components/HourlyForecast'
import { ForecastList } from '../components/ForecastList'
import { EnvironmentCards } from '../components/EnvironmentCards'
import { SunriseSetCard } from '../components/SunriseSetCard'
import { MoonCard } from '../components/MoonCard'
import { WarningBanner } from '../components/WarningBanner'
import { DetailPayload } from '../components/DetailDialogs'
import { AqiDetailDialog } from '../components/AqiDetailDialog'
import { UvDetailDialog } from '../components/UvDetailDialog'
import { HumidityDetailDialog } from '../components/HumidityDetailDialog'
import { WindDetailDialog } from '../components/WindDetailDialog'
import { VisibilityDetailDialog } from '../components/VisibilityDetailDialog'
import { PressureDetailDialog } from '../components/PressureDetailDialog'
import { TemperatureTrendDialog } from '../components/TemperatureTrendDialog'
import { SunriseDetailDialog } from '../components/SunriseDetailDialog'
import { MoonDetailDialog } from '../components/MoonDetailDialog'
import { PrecipDetailDialog } from '../components/PrecipDetailDialog'
import { AverageTempCard } from '../components/AverageTempCard'
import { FeelsLikeCard } from '../components/FeelsLikeCard'
import { router, promptAction } from '@kit.ArkUI'

/** 单个城市的天气状态 — @ObservedV2 保证数组元素属性变化能被 UI 感知 */
@ObservedV2
class CityWeatherState {
  city: FavoriteCity
  @Trace currentWeather: CurrentWeatherData | null = null
  @Trace hourlyData: HourlyForecastItem[] = []
  @Trace forecastDays: ForecastDay[] = []
  @Trace airQuality: AirQualityData | null = null
  @Trace warnings: WarningItem[] = []
  @Trace forecast15Days: ForecastDay[] = []
  @Trace forecastMode7Day: boolean = true
  @Trace backgroundUrl: string = ''
  @Trace isClearBg: boolean = false
  @Trace isLoading: boolean = false
  @Trace errorMessage: string = ''

  @Trace isAutoLocated: boolean = false

  constructor(city: FavoriteCity, isAutoLocated: boolean = false) {
    this.city = city
    this.isAutoLocated = isAutoLocated
  }
}

/**
 * 停云见晴主页面
 * Swiper 左右滑动切换城市，底部悬浮栏含圆点指示器与列表图标
 */
@Entry
@Component
struct Index {
  @State cityStates: CityWeatherState[] = []
  @State currentIndex: number = 0
  @State isReady: boolean = false
  @State isRefreshing: boolean = false
  @StorageLink('tempUnit') tempUnit: string = '°C'

  @State envPayload: DetailPayload = new DetailPayload()
  aqiController: CustomDialogController = new CustomDialogController({
    builder: AqiDetailDialog({ payload: $envPayload }),
    alignment: DialogAlignment.Bottom,
    customStyle: true
  })
  uvController: CustomDialogController = new CustomDialogController({
    builder: UvDetailDialog({ payload: $envPayload }),
    alignment: DialogAlignment.Bottom,
    customStyle: true
  })
  humidityController: CustomDialogController = new CustomDialogController({
    builder: HumidityDetailDialog({ payload: $envPayload }),
    alignment: DialogAlignment.Bottom,
    customStyle: true
  })
  windController: CustomDialogController = new CustomDialogController({
    builder: WindDetailDialog({ payload: $envPayload }),
    alignment: DialogAlignment.Bottom,
    customStyle: true
  })
  visController: CustomDialogController = new CustomDialogController({
    builder: VisibilityDetailDialog({ payload: $envPayload }),
    alignment: DialogAlignment.Bottom,
    customStyle: true
  })
  pressureController: CustomDialogController = new CustomDialogController({
    builder: PressureDetailDialog({ payload: $envPayload }),
    alignment: DialogAlignment.Bottom,
    customStyle: true
  })
  tempController: CustomDialogController = new CustomDialogController({
    builder: TemperatureTrendDialog({ payload: $envPayload }),
    alignment: DialogAlignment.Bottom,
    customStyle: true
  })
  sunController: CustomDialogController = new CustomDialogController({
    builder: SunriseDetailDialog({ payload: $envPayload }),
    alignment: DialogAlignment.Bottom,
    customStyle: true
  })
  moonController: CustomDialogController = new CustomDialogController({
    builder: MoonDetailDialog({ payload: $envPayload }),
    alignment: DialogAlignment.Bottom,
    customStyle: true
  })
  precipController: CustomDialogController = new CustomDialogController({
    builder: PrecipDetailDialog({ payload: $envPayload }),
    alignment: DialogAlignment.Bottom,
    customStyle: true
  })

  async aboutToAppear(): Promise<void> {
    await TemperatureService.getInstance().init(getContext(this))
    await this.initCities()
    // 初始化完成后启动持续定位监听，位置变化时自动刷新天气
    startContinuousLocation((newLocation: LocationResult) => {
      this.onLocationSignificantlyChanged(newLocation)
    })
  }

  aboutToDisappear(): void {
    stopContinuousLocation()
  }

  onPageShow(): void {
    this.handleReturnFromSearch()
  }

  /** 填充 envPayload 通用数据 */
  private async prepareEnvPayload(state: CityWeatherState): Promise<void> {
    this.envPayload.hourlyData = state.hourlyData
    this.envPayload.forecastDays = state.forecastDays
    this.envPayload.forecast15Days = state.forecast15Days
    this.envPayload.currentWeather = state.currentWeather
    this.envPayload.cityName = state.city.name
    this.envPayload.aqiData = state.airQuality

    const snapshot = await loadYesterdaySnapshot(getContext(this), state.city.id)
    if (snapshot) {
      this.envPayload.forecastDays = [snapshot.forecastDay, ...this.envPayload.forecastDays]
      this.envPayload.hourlyData = [...this.envPayload.hourlyData, ...snapshot.hourlyData]
    }
  }

  async openAqiDetail(state: CityWeatherState): Promise<void> {
    await this.prepareEnvPayload(state)
    this.aqiController.open()
  }

  async openUvDetail(state: CityWeatherState): Promise<void> {
    await this.prepareEnvPayload(state)
    this.uvController.open()
  }

  async openHumidityDetail(state: CityWeatherState): Promise<void> {
    await this.prepareEnvPayload(state)
    this.humidityController.open()
  }

  async openWindDetail(state: CityWeatherState): Promise<void> {
    await this.prepareEnvPayload(state)
    this.windController.open()
  }

  async openVisDetail(state: CityWeatherState): Promise<void> {
    await this.prepareEnvPayload(state)
    this.visController.open()
  }

  async openPressureDetail(state: CityWeatherState): Promise<void> {
    await this.prepareEnvPayload(state)
    this.pressureController.open()
  }

  async openTempDetail(state: CityWeatherState): Promise<void> {
    await this.prepareEnvPayload(state)
    this.tempController.open()
  }

  async openSunriseDetail(state: CityWeatherState): Promise<void> {
    await this.prepareEnvPayload(state)
    this.sunController.open()
  }

  async openMoonDetail(state: CityWeatherState): Promise<void> {
    await this.prepareEnvPayload(state)
    this.moonController.open()
  }

  async openPrecipDetail(state: CityWeatherState): Promise<void> {
    await this.prepareEnvPayload(state)
    this.precipController.open()
  }

  /** 从搜索页返回时：刷新列表 + 定位到指定城市 */
  async handleReturnFromSearch(): Promise<void> {
    await this.refreshFromFavorites()

    const targetCityId = AppStorage.get<string>('navigateToCityId')
    if (targetCityId) {
      const index = this.cityStates.findIndex(s => s.city.id === targetCityId)
      if (index >= 0) {
        this.currentIndex = index
      }
      AppStorage.delete('navigateToCityId')
    }
  }

  /** 初始化：定位 + 城市查询完成后立即展示，天气数据后台加载 */
  async initCities(): Promise<void> {
    const states: CityWeatherState[] = []

    // 1. 自动定位城市
    const location = await getDeviceLocation(getContext(this))
    const autoCity = await cityLookup(`${location.longitude},${location.latitude}`)
    const autoFav: FavoriteCity = {
      name: autoCity.name, id: autoCity.id,
      adm1: autoCity.adm1, adm2: autoCity.adm2,
      lat: autoCity.lat, lon: autoCity.lon,
      utcOffset: autoCity.utcOffset
    }
    states.push(new CityWeatherState(autoFav, true))

    // 2. 收藏城市（去重）
    const favorites = await getFavorites(getContext(this))
    for (const fav of favorites) {
      if (fav.id !== states[0].city.id) {
        states.push(new CityWeatherState(fav))
      }
    }

    this.cityStates = states
    this.isReady = true

    await this.loadCityWeather(0)
    this.loadRemainingWeather()
  }

  /** 从收藏列表刷新 */
  async refreshFromFavorites(): Promise<void> {
    const favorites = await getFavorites(getContext(this))
    const autoCity = this.cityStates.length > 0 ? this.cityStates[0].city : null
    const newStates: CityWeatherState[] = []

    if (autoCity) {
      newStates.push(new CityWeatherState(autoCity, true))
    }
    for (const fav of favorites) {
      if (!autoCity || fav.id !== autoCity.id) {
        newStates.push(new CityWeatherState(fav))
      }
    }

    this.cityStates = newStates
    if (this.currentIndex >= newStates.length) {
      this.currentIndex = 0
    }

    // 后台加载天气（不阻塞 UI 渲染，避免页面切换卡顿）
    this.loadCityWeather(this.currentIndex)
    this.loadRemainingWeather()
  }

  /** 后台加载剩余城市 */
  loadRemainingWeather(): void {
    for (let i = 0; i < this.cityStates.length; i++) {
      if (i !== this.currentIndex) {
        this.loadCityWeather(i)
      }
    }
  }

  /** 加载单个城市天气 */
  async loadCityWeather(index: number): Promise<void> {
    const state = this.cityStates[index]
    if (!state || state.isLoading) {
      return
    }
    state.isLoading = true
    state.errorMessage = ''

    try {
      const locationId = state.city.id
      const results = await Promise.allSettled([
        getCurrentWeather(locationId),
        getForecast(locationId),
        getHourlyForecast(locationId),
        getAirQuality(locationId),
        getWeatherWarning(locationId),
        getForecast15D(locationId)
      ])

      if (results[0].status === 'fulfilled') {
        state.currentWeather = results[0].value
        state.backgroundUrl = getWeatherBackgroundUrl(results[0].value.text, results[0].value.icon, state.city.utcOffset)
        state.isClearBg = isClearWeatherBackground(results[0].value.text, results[0].value.icon, state.city.utcOffset)
      } else {
        state.errorMessage = '获取实时天气失败'
      }
      if (results[1].status === 'fulfilled') {
        state.forecastDays = results[1].value
      }
      if (results[2].status === 'fulfilled') {
        state.hourlyData = results[2].value
      }
      if (results[3].status === 'fulfilled') {
        state.airQuality = results[3].value
      } else {
        console.warn(`[Index] AQI 数据获取失败 (${state.city.name}): ${results[3].reason}`)
      }
      if (results[4].status === 'fulfilled') {
        state.warnings = results[4].value
      }
      if (results[5].status === 'fulfilled') {
        state.forecast15Days = results[5].value
      }

      if (results[1].status === 'fulfilled' && results[2].status === 'fulfilled') {
        saveTodaySnapshot(getContext(this), state.city.id, results[1].value[0], results[2].value)
      }
    } catch (error) {
      state.errorMessage = (error as Error).message || '加载失败'
    } finally {
      state.isLoading = false
    }
  }

  /** 下拉刷新的自定义指示器，橙色图标 + 白色文字，深色背景下清晰可见 */
  @Builder
  refreshIndicator() {
    Row() {
      LoadingProgress().width(22).height(22).color('#ff9f43')
      Text('刷新中...')
        .fontSize(13)
        .fontColor('rgba(255,255,255,0.85)')
        .margin({ left: 8 })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }

  /** 重定位防抖：避免短时间内多次触发城市切换 */
  private relocatePending: FavoriteCity | null = null

  /**
   * 位置显著变化时的回调
   * 通过反向地理编码获取新城市，如果城市ID与当前不同则更新第一个城市卡片并刷新天气
   */
  async onLocationSignificantlyChanged(newLocation: LocationResult): Promise<void> {
    if (this.relocatePending) {
      return // 上一次重定位仍在处理中，忽略此次回调
    }

    try {
      const cityLoc = await cityLookup(`${newLocation.longitude},${newLocation.latitude}`)
      const autoCity: FavoriteCity = {
        name: cityLoc.name, id: cityLoc.id,
        adm1: cityLoc.adm1, adm2: cityLoc.adm2,
        lat: cityLoc.lat, lon: cityLoc.lon,
        utcOffset: cityLoc.utcOffset
      }
      const currentAutoCity = this.cityStates.length > 0 ? this.cityStates[0].city : null

      // 城市未变化则跳过
      if (currentAutoCity && currentAutoCity.id === autoCity.id) {
        console.info(`[Index] 定位城市未变: ${autoCity.name}`)
        return
      }

      console.info(`[Index] 定位城市变化: ${currentAutoCity?.name ?? '无'} → ${autoCity.name}`)
      await this.applyNewAutoCity(autoCity)
    } catch (error) {
      console.warn(`[Index] 反向地理编码失败: ${JSON.stringify(error)}`)
    }
  }

  /** 应用新的自动定位城市并刷新天气 */
  async applyNewAutoCity(newCity: FavoriteCity): Promise<void> {
    this.relocatePending = newCity

    const newCityState = new CityWeatherState(newCity, true)

    // 替换第一个元素（自动定位城市），保留收藏城市（去重）
    const newStates: CityWeatherState[] = [newCityState]
    for (let i = 1; i < this.cityStates.length; i++) {
      if (this.cityStates[i].city.id !== newCity.id) {
        newStates.push(this.cityStates[i])
      }
    }

    this.cityStates = newStates
    this.currentIndex = 0

    // 加载天气数据
    try {
      await this.loadCityWeather(0)
      this.loadRemainingWeather()
    } finally {
      this.relocatePending = null
    }
  }

  /**
   * 下拉刷新处理
   * 对自动定位城市（index 0）：先检查位置是否有变化，有变化则更新城市再刷新天气
   * 对收藏城市：直接刷新天气
   */
  async handleRefresh(index: number): Promise<void> {
    try {
      if (index === 0) {
        // 自动定位城市：重新获取位置，检查是否切换城市
        try {
          const location = await getDeviceLocation(getContext(this))
          const cityLoc = await cityLookup(`${location.longitude},${location.latitude}`)
          const autoCity: FavoriteCity = {
            name: cityLoc.name, id: cityLoc.id,
            adm1: cityLoc.adm1, adm2: cityLoc.adm2,
            lat: cityLoc.lat, lon: cityLoc.lon,
            utcOffset: cityLoc.utcOffset
          }
          if (this.cityStates.length > 0 && this.cityStates[0].city.id !== autoCity.id) {
            console.info(`[Index] 下拉刷新检测到城市变化: ${this.cityStates[0].city.name} → ${autoCity.name}`)
            await this.applyNewAutoCity(autoCity)
            return // applyNewAutoCity 已刷新天气
          }
        } catch {
          // 获取位置失败：降级为直接刷新当前城市天气
          console.warn('[Index] 下拉刷新时获取位置失败，仅刷新天气')
        }
      }

      // 刷新当前城市天气
      await this.loadCityWeather(index)
      this.loadRemainingWeather()
    } finally {
      this.isRefreshing = false
    }
  }

  /**
   * 从7天预报中查找距下次满月天数
   * 满月: moonPhaseIcon === '804' 或 moonPhase === '满月'
   */
  private getNextFullMoon(forecastDays: ForecastDay[]): string {
    for (let i = 0; i < forecastDays.length; i++) {
      const day = forecastDays[i]
      if (day.moonPhaseIcon === '804' || day.moonPhase === '满月') {
        if (i === 0) {
          return '今日满月 🌕'
        }
        return `距满月 ${i} 天`
      }
    }
    return ''
  }

  build() {
    Stack() {
      if (!this.isReady) {
        Column() {
          LoadingProgress().width(40).height(40).color('#007bff')
          Text('加载中...').fontSize(15).fontColor('#888').margin({ top: 12 })
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#1C1C1E')
      } else if (this.cityStates.length === 0) {
        Column() {
          Text('暂无城市').fontSize(18).fontColor('#aaa')
          Text('请点击下方列表图标添加').fontSize(14).fontColor('#888').margin({ top: 8 })
        }
        .width('100%').height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#1C1C1E')
      } else {
        Swiper() {
          ForEach(this.cityStates, (state: CityWeatherState, index: number) => {
            Stack() {
              // 天气背景图
              if (state.backgroundUrl) {
                Image(state.backgroundUrl)
                  .width('100%').height('100%')
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
                  .objectFit(ImageFit.Cover)
              }

              // // 深色遮罩
              // Column()
              //   .width('100%').height('100%')
              //   .backgroundColor(state.backgroundUrl ? 'rgba(0,0,0,0.55)' : '#1a1a2e')

              // 内容区（支持下拉刷新，自定义指示器增强对比度）
              Refresh({ refreshing: $$this.isRefreshing, builder: this.refreshIndicator }) {
                Scroll() {
                  Column() {
                    if (state.isLoading) {
                      Column() {
                        LoadingProgress().width(36).height(36).color('#ffffff')
                        Text('加载天气数据...').fontSize(14).fontColor('#ccc').margin({ top: 10 })
                      }.width('100%').padding({ top: 80, bottom: 40 })
                    } else if (state.errorMessage) {
                      Text(state.errorMessage)
                        .fontSize(15).fontColor('#ff6b6b')
                        .textAlign(TextAlign.Center)
                        .width('100%').padding({ top: 60 })
                    } else {
                      // 预警横幅
                      if (state.warnings.length > 0) {
                        WarningBanner({ warnings: state.warnings })
                      }

                      CurrentWeatherCard({
                        weatherData: state.currentWeather,
                        cityName: state.city.name,
                        tempMax: state.forecastDays.length > 0 ? state.forecastDays[0].tempMax : '',
                        tempMin: state.forecastDays.length > 0 ? state.forecastDays[0].tempMin : '',
                        onTempClick: () => { this.openTempDetail(state) }
                      })

                      if (state.hourlyData.length > 0) {
                        HourlyForecast({
                          hourlyData: state.hourlyData,
                          isClearBg: state.isClearBg,
                          onItemClick: (_index: number) => {
                            this.openTempDetail(state)
                          }
                        })
                      }

                      if (state.forecastDays.length > 0) {
                        Column() {
                          // 7天 / 15天 切换
                          Row({ space: 0 }) {
                            Button('7天')
                              .fontSize(12)
                              .height(28)
                              .padding({ left: 14, right: 14 })
                              .borderRadius(14)
                              .backgroundColor(state.isClearBg ?
                                (state.forecastMode7Day ? 'rgba(255,255,255,0.30)' : 'rgba(255,255,255,0.08)') :
                                (state.forecastMode7Day ? 'rgba(0,0,0,0.30)' : 'rgba(0,0,0,0.08)'))
                              .fontColor('#ffffff')
                              .onClick(() => {
                                state.forecastMode7Day = true
                              })
                            Blank().width(4)
                            Button('15天')
                              .fontSize(12)
                              .height(28)
                              .padding({ left: 14, right: 14 })
                              .borderRadius(14)
                              .backgroundColor(state.isClearBg ?
                                (state.forecastMode7Day ? 'rgba(255,255,255,0.08)' : 'rgba(255,255,255,0.30)') :
                                (state.forecastMode7Day ? 'rgba(0,0,0,0.08)' : 'rgba(0,0,0,0.30)'))
                              .fontColor('#ffffff')
                              .onClick(() => {
                                state.forecastMode7Day = false
                              })
                          }
                          .width('100%')
                          .justifyContent(FlexAlign.End)
                          .padding({ right: 12, top: 6, bottom: 2 })

                          ForecastList({
                            forecastDays: state.forecastMode7Day ? state.forecastDays : state.forecast15Days,
                            title: state.forecastMode7Day ? '未来 7 天' : '未来 15 天',
                            isClearBg: state.isClearBg
                          })
                        }
                      }

                      if (state.forecastDays.length > 0) {
                        SunriseSetCard({
                          sunrise: state.forecastDays[0].sunrise,
                          sunset: state.forecastDays[0].sunset,
                          forecastDays: state.forecastDays,
                          isClearBg: state.isClearBg,
                          onCardClick: () => { this.openSunriseDetail(state) }
                        })
                      }

                      if (state.forecastDays.length > 0) {
                        MoonCard({
                          moonPhase: state.forecastDays[0].moonPhase,
                          moonPhaseIcon: state.forecastDays[0].moonPhaseIcon,
                          moonrise: state.forecastDays[0].moonrise,
                          moonset: state.forecastDays[0].moonset,
                          nextFullMoon: this.getNextFullMoon(state.forecastDays),
                          isClearBg: state.isClearBg,
                          onCardClick: () => { this.openMoonDetail(state) }
                        })
                      }

                      EnvironmentCards({
                        aqiData: state.airQuality,
                        isClearBg: state.isClearBg,
                        humidity: state.currentWeather?.humidity ?? '',
                        dew: state.currentWeather?.dew ?? '',
                        uvIndex: state.forecastDays.length > 0 ? state.forecastDays[0].uvIndex : '',
                        windDir: state.currentWeather?.windDir ?? '',
                        windScale: state.currentWeather?.windScale ?? '',
                        windSpeed: state.currentWeather?.windSpeed ?? '',
                        wind360: state.currentWeather?.wind360 ?? '',
                        visValue: state.currentWeather?.vis ?? '',
                        pressure: state.currentWeather?.pressure ?? '',
                        pop: state.hourlyData.length > 0 ? state.hourlyData[0].pop : '',
                        precip: state.currentWeather?.precip ?? '',
                        onAqiClick: () => { this.openAqiDetail(state) },
                        onUvClick: () => { this.openUvDetail(state) },
                        onHumidityClick: () => { this.openHumidityDetail(state) },
                        onWindClick: () => { this.openWindDetail(state) },
                        onVisClick: () => { this.openVisDetail(state) },
                        onPressureClick: () => { this.openPressureDetail(state) },
                        onPrecipClick: () => { this.openPrecipDetail(state) },
                        tomorrowPrecip: state.forecastDays.length > 1 ? state.forecastDays[1].precip : ''
                      })

                      AverageTempCard({
                        tempMax: state.forecastDays.length > 0 ? state.forecastDays[0].tempMax : '',
                        tempMin: state.forecastDays.length > 0 ? state.forecastDays[0].tempMin : '',
                        currentTemp: state.currentWeather?.temp ?? '',
                        isClearBg: state.isClearBg
                      })

                      FeelsLikeCard({
                        feelsLike: state.currentWeather?.feelsLike ?? '',
                        currentTemp: state.currentWeather?.temp ?? '',
                        isClearBg: state.isClearBg
                      })

                      Column().height(80)
                    }
                  }
                  .width('100%')
                }
                .scrollable(ScrollDirection.Vertical)
                .scrollBar(BarState.Off)
                .edgeEffect(EdgeEffect.Spring)
                .width('100%').height('100%')
              }
              .onRefreshing(async () => {
                await this.handleRefresh(index)
              })
            }
            .width('100%').height('100%')
          }, (state: CityWeatherState) => state.city.id)
        }
        .index($$this.currentIndex)
        .width('100%').height('100%')
        .loop(false)
        .indicator(false)
        .onChange((index: number) => {
          this.currentIndex = index
        })

        // 底部悬浮栏
        Row() {
          Blank().width(40)

          Row({ space: 8 }) {
            ForEach(this.cityStates, (state: CityWeatherState, dotIndex: number) => {
              if (state.isAutoLocated) {
                // 指南针图标 — 外圈 + 内芯
                Stack() {
                  Circle()
                    .width(dotIndex === this.currentIndex ? 10 : 8)
                    .height(dotIndex === this.currentIndex ? 10 : 8)
                    .stroke(dotIndex === this.currentIndex ? '#ffffff' : 'rgba(255,255,255,0.35)')
                    .strokeWidth(1.5)
                    .fill(Color.Transparent)
                  Circle()
                    .width(dotIndex === this.currentIndex ? 4 : 3)
                    .height(dotIndex === this.currentIndex ? 4 : 3)
                    .fill(dotIndex === this.currentIndex ? '#ffffff' : 'rgba(255,255,255,0.35)')
                }
              } else {
                Circle()
                  .width(dotIndex === this.currentIndex ? 8 : 6)
                  .height(dotIndex === this.currentIndex ? 8 : 6)
                  .fill(dotIndex === this.currentIndex ? '#ffffff' : 'rgba(255,255,255,0.35)')
              }
            })
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)

          // 城市列表按钮
          Button({ type: ButtonType.Circle }) {
            Text('🗺')
              .fontSize(18)
              .fontColor('#ffffff')
          }
          .width(40).height(40)
          .backgroundColor('rgba(255,255,255,0.12)')
          .margin({ right: 8 })
          .onClick(() => {
            promptAction.showToast({ message: '地图功能即将上线', duration: 1500 })
          })

          Button({ type: ButtonType.Circle }) {
            Text('☰')
              .fontSize(18)
              .fontColor('#ffffff')
          }
          .width(40).height(40)
          .backgroundColor('rgba(255,255,255,0.12)')
          .onClick(() => router.pushUrl({ url: 'pages/SearchPage' }))
        }
        .width('100%')
        .height(56)
        .padding({ left: 12, right: 12 })
        .backgroundColor('rgba(0,0,0,0.45)')
        .backdropBlur(16)
        .borderRadius({ topLeft: 20, topRight: 20 })
        .position({ x: 0, y: '100%' })
        .translate({ y: -56 })
      }
    }
    .width('100%').height('100%')
    .backgroundColor('#1C1C1E')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
