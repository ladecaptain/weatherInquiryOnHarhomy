import { CityLocation, CurrentWeatherData, ForecastDay } from '../model/WeatherModel'
import { cityLookupAll, getCurrentWeather, getForecast, cityLookup } from '../api/WeatherApi'
import { addFavorite, removeFavorite, getFavorites, FavoriteCity } from '../services/FavoriteCityManager'
import { getWeatherBackgroundUrl, formatCityLocalTime } from '../utils/WeatherUtils'
import { hasLocationPermission, getDeviceLocation } from '../services/LocationService'
import { promptAction, router } from '@kit.ArkUI'

/** 收藏城市 + 天气快照 — @ObservedV2 保证属性变化触发 UI 刷新 */
@ObservedV2
class CityCardEntry {
  city: FavoriteCity
  @Trace weather: CurrentWeatherData | null = null
  @Trace tempMax: string = ''
  @Trace tempMin: string = ''
  @Trace localTime: string = ''
  @Trace bgUrl: string = ''
  @Trace isLoading: boolean = true
  @Trace isAutoLocated: boolean = false

  constructor(city: FavoriteCity, isAutoLocated: boolean = false) {
    this.city = city
    this.isAutoLocated = isAutoLocated
  }
}

/** 搜索结果条目 — @ObservedV2 保证天气数据异步加载后 UI 自动刷新 */
@ObservedV2
class SearchResultEntry {
  city: CityLocation
  @Trace weather: CurrentWeatherData | null = null
  @Trace tempMax: string = ''
  @Trace tempMin: string = ''
  @Trace localTime: string = ''
  @Trace isLoading: boolean = true

  constructor(city: CityLocation) {
    this.city = city
  }
}

/**
 * 城市管理页
 * 深色背景，搜索栏添加城市，卡片展示已收藏城市天气
 * 点击卡片跳转首页，右滑卡片出现红色删除按钮
 */
@Entry
@Component
struct SearchPage {
  @State searchText: string = ''
  @State searchResults: SearchResultEntry[] = []
  @State isSearching: boolean = false
  @State cards: CityCardEntry[] = []
  @State cardsReady: boolean = false

  async aboutToAppear(): Promise<void> {
    await this.initCards()
  }

  /** 初始化卡片：构建列表后立即展示，天气后台加载 */
  async initCards(): Promise<void> {
    const entries: CityCardEntry[] = []

    if (hasLocationPermission()) {
      const location = await getDeviceLocation(getContext(this))
      const autoCity = await cityLookup(`${location.longitude},${location.latitude}`)
      entries.push(new CityCardEntry({
        name: autoCity.name, id: autoCity.id,
        adm1: autoCity.adm1, adm2: autoCity.adm2,
        lat: autoCity.lat, lon: autoCity.lon,
        utcOffset: autoCity.utcOffset
      }, true))
    }

    const favorites = await getFavorites(getContext(this))
    for (const fav of favorites) {
      if (entries.length === 0 || fav.id !== entries[0].city.id) {
        entries.push(new CityCardEntry(fav))
      }
    }

    this.cards = entries
    this.cardsReady = true
    this.loadAllCardWeather()
  }

  /** 后台加载所有卡片天气 */
  loadAllCardWeather(): void {
    for (let i = 0; i < this.cards.length; i++) {
      this.loadCardWeather(i)
    }
  }

  /** 加载单张卡片的天气 */
  async loadCardWeather(index: number): Promise<void> {
    const entry = this.cards[index]
    if (!entry) {
      return
    }
    entry.isLoading = true
    entry.localTime = formatCityLocalTime(entry.city.utcOffset ?? '')
    try {
      const results = await Promise.all([
        getCurrentWeather(entry.city.id),
        getForecast(entry.city.id)
      ])
      entry.weather = results[0] as CurrentWeatherData
      const forecastArr = results[1] as ForecastDay[]
      if (forecastArr.length > 0) {
        entry.tempMax = forecastArr[0].tempMax
        entry.tempMin = forecastArr[0].tempMin
      }
      entry.bgUrl = entry.weather ? getWeatherBackgroundUrl(entry.weather.text, entry.weather.icon, entry.city.utcOffset) : ''
    } catch {
      // 静默失败
    } finally {
      entry.isLoading = false
    }
  }

  /** 执行城市搜索 */
  async doSearch(): Promise<void> {
    const keyword = this.searchText.trim()
    if (!keyword) {
      promptAction.showToast({ message: '请输入城市名称', duration: 1500 })
      return
    }
    this.isSearching = true
    try {
      const locations = await cityLookupAll(keyword)
      if (locations.length === 0) {
        promptAction.showToast({ message: '未找到匹配城市', duration: 1500 })
        this.searchResults = []
        return
      }
      // 构建条目列表，显示城市名后立即启动后台天气加载
      this.searchResults = locations.map(loc => new SearchResultEntry(loc))
      this.loadSearchResultsWeather()
    } catch {
      promptAction.showToast({ message: '搜索失败，请检查网络', duration: 1500 })
    } finally {
      this.isSearching = false
    }
  }

  /** 后台加载所有搜索结果的天气 */
  loadSearchResultsWeather(): void {
    for (let i = 0; i < this.searchResults.length; i++) {
      this.loadSearchResultWeather(i)
    }
  }

  /** 加载单个搜索结果的天气 + 预测（用于最低/最高温） */
  async loadSearchResultWeather(index: number): Promise<void> {
    const entry = this.searchResults[index]
    if (!entry) {
      return
    }
    entry.isLoading = true
    entry.localTime = formatCityLocalTime(entry.city.utcOffset)
    try {
      const results = await Promise.all([
        getCurrentWeather(entry.city.id),
        getForecast(entry.city.id)
      ])
      entry.weather = results[0] as CurrentWeatherData
      const forecastArr = results[1] as ForecastDay[]
      if (forecastArr.length > 0) {
        entry.tempMax = forecastArr[0].tempMax
        entry.tempMin = forecastArr[0].tempMin
      }
    } catch {
      // 静默失败，天气数据不可用时仅显示城市基本信息
    } finally {
      entry.isLoading = false
    }
  }

  /** 添加城市到收藏 */
  async doAddCity(loc: CityLocation): Promise<void> {
    const fav: FavoriteCity = {
      name: loc.name, id: loc.id,
      adm1: loc.adm1, adm2: loc.adm2,
      lat: loc.lat, lon: loc.lon,
      utcOffset: loc.utcOffset
    }
    await addFavorite(getContext(this), fav)

    const alreadyExists = this.cards.some(c => c.city.id === fav.id)
    if (!alreadyExists) {
      const entry = new CityCardEntry(fav)
      this.cards.unshift(entry)
      this.loadCardWeather(0)
    }

    promptAction.showToast({ message: `已添加 ${loc.name}`, duration: 1500 })
    this.searchText = ''
    this.searchResults = []
  }

  /** 移除收藏 */
  async doRemoveCity(cityId: string, cityName: string): Promise<void> {
    await removeFavorite(getContext(this), cityId)
    this.cards = this.cards.filter(c => c.city.id !== cityId)
    promptAction.showToast({ message: `已移除 ${cityName}`, duration: 1500 })
  }

  /** 点击卡片 → 导航到首页该城市 */
  navigateToCity(city: FavoriteCity): void {
    AppStorage.setOrCreate<string>('navigateToCityId', city.id)
    router.back()
  }

  /** 右滑删除按钮 Builder */
  @Builder
  DeleteSwipeButton(entry: CityCardEntry) {
    Button() {
      Text('删除')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#ffffff')
    }
    .width(80)
    .height('100%')
    .backgroundColor('#e74c3c')
    .borderRadius(16)
    .onClick(() => this.doRemoveCity(entry.city.id, entry.city.name))
  }

  build() {
    Column() {
      // ── 顶部标题 ──
      Row() {
        Text('天气查询')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#ffffff')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // ── 搜索栏 ──
      Row() {
        TextInput({ text: this.searchText, placeholder: '搜索城市...' })
          .layoutWeight(1)
          .height(44)
          .fontSize(15)
          .fontColor('#ffffff')
          .placeholderColor('rgba(255,255,255,0.3)')
          .backgroundColor('rgba(255,255,255,0.1)')
          .borderRadius(22)
          .padding({ left: 16, right: 16 })
          .onChange((value: string) => this.searchText = value)
          .onSubmit(() => this.doSearch())
          .caretColor('#ffffff')

        Button('搜索')
          .fontSize(14)
          .height(40)
          .padding({ left: 16, right: 16 })
          .borderRadius(20)
          .backgroundColor('rgba(255,255,255,0.15)')
          .fontColor('#ffffff')
          .margin({ left: 8 })
          .onClick(() => this.doSearch())
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 12 })

      // ── 搜索中 ──
      if (this.isSearching) {
        Column() {
          LoadingProgress().width(32).height(32).color('rgba(255,255,255,0.6)')
          Text('搜索中...').fontSize(13).fontColor('rgba(255,255,255,0.4)').margin({ top: 8 })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      }
      // ── 搜索结果 ──
      else if (this.searchResults.length > 0) {
        List() {
          ForEach(this.searchResults, (entry: SearchResultEntry) => {
            ListItem() {
              Row() {
                // 左侧：城市名 + 行政区域 + 天气信息
                Column() {
                  // 第1行：城市名
                  Text(entry.city.name)
                    .fontSize(17)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#ffffff')
                  // 第2行：行政区域
                  Text(`${entry.city.adm1} · ${entry.city.adm2}`)
                    .fontSize(11)
                    .fontColor('rgba(255,255,255,0.35)')
                    .margin({ top: 1 })

                  // 第3行：天气信息（异步加载）
                  if (entry.isLoading) {
                    Row() {
                      LoadingProgress()
                        .width(12).height(12)
                        .color('rgba(255,255,255,0.3)')
                      Text(' 加载中...')
                        .fontSize(11)
                        .fontColor('rgba(255,255,255,0.3)')
                    }
                    .margin({ top: 5 })
                  } else if (entry.weather) {
                    Row() {
                      Text(entry.weather.text)
                        .fontSize(13)
                        .fontColor('#4fc3f7')
                      Text(` ${entry.weather.temp}°`)
                        .fontSize(13)
                        .fontWeight(FontWeight.Medium)
                        .fontColor('#ffffff')
                      if (entry.tempMax && entry.tempMin) {
                        Text(`  ↑${entry.tempMax}° ↓${entry.tempMin}°`)
                          .fontSize(11)
                          .fontColor('rgba(255,255,255,0.35)')
                      }
                    }
                    .margin({ top: 5 })
                  }
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                // 右侧：当地时间 + 添加按钮
                Column({ space: 6 }) {
                  Text(entry.localTime)
                    .fontSize(13)
                    .fontColor('rgba(255,255,255,0.55)')

                  Button('添加')
                    .fontSize(12)
                    .height(30)
                    .padding({ left: 16, right: 16 })
                    .borderRadius(15)
                    .backgroundColor('rgba(255,255,255,0.12)')
                    .fontColor('#ffffff')
                    .onClick(() => this.doAddCity(entry.city))
                }
                .alignItems(HorizontalAlign.End)
                .justifyContent(FlexAlign.Center)
              }
              .width('100%')
            }
            .padding({ left: 20, right: 20, top: 14, bottom: 14 })
          })
        }
        .width('100%')
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: 'rgba(255,255,255,0.06)' })
        .scrollBar(BarState.Off)
      }
      // ── 城市卡片列表 ──
      else if (this.cardsReady) {
        List({ space: 12 }) {
          ForEach(this.cards, (entry: CityCardEntry) => {
            ListItem() {
              // 天气卡片
              Stack() {
                if (entry.bgUrl) {
                  Image(entry.bgUrl)
                    .width('100%').height('100%')
                    .objectFit(ImageFit.Cover)
                    .borderRadius(16)
                }

                Column()
                  .width('100%').height('100%')
                  .backgroundColor(entry.bgUrl ? 'rgba(0,0,0,0.45)' : 'rgba(255,255,255,0.06)')
                  .backdropBlur(12)
                  .borderRadius(16)

                Row() {
                  // 左列：城市名+图标 / 时间 / 天气描述
                  Column() {
                    // 第1行：城市名 + 天气图标（同行，紧挨着）
                    Row({ space: 10 }) {
                      Text(entry.city.name)
                        .fontSize(22)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#ffffff')
                      if (entry.weather?.icon) {
                        Image($rawfile(`weather_${entry.weather.icon}.svg`))
                          .width(32).height(32)
                      }
                    }
                    // 第2行：时间 or 定位标识
                    Text(entry.isAutoLocated ? '我的位置' : entry.localTime)
                      .fontSize(13)
                      .fontColor('rgba(255,255,255,0.4)')
                      .margin({ top: 2 })
                    // 第3行：天气描述
                    if (entry.isLoading) {
                      LoadingProgress()
                        .width(12).height(12)
                        .color('rgba(255,255,255,0.35)')
                        .margin({ top: 6 })
                    } else if (entry.weather) {
                      Text(entry.weather.text)
                        .fontSize(14)
                        .fontColor('rgba(255,255,255,0.7)')
                        .margin({ top: 6 })
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  // 右列：当前气温 / 最低-最高
                  Column() {
                    if (entry.weather) {
                      Text(`${entry.weather.temp}°`)
                        .fontSize(36)
                        .fontWeight(FontWeight.Lighter)
                        .fontColor('#ffffff')
                    }
                    if (entry.tempMax && entry.tempMin) {
                      Text(`↑${entry.tempMax}° ↓${entry.tempMin}°`)
                        .fontSize(12)
                        .fontColor('rgba(255,255,255,0.35)')
                        .margin({ top: 6 })
                    }
                  }
                  .alignItems(HorizontalAlign.End)
                }
                .width('100%').height('100%')
                .padding(16)
              }
              .width('100%')
              .height(115)
              .borderRadius(16)
              .clip(true)
              .onClick(() => this.navigateToCity(entry.city))
            }
            .swipeAction({
              end: {
                builder: () => { this.DeleteSwipeButton(entry) },
                actionAreaDistance: 80
              }
            })
            .width('100%')
          })

          if (this.cards.length === 0) {
            ListItem() {
              Column() {
                Text('暂无城市')
                  .fontSize(16).fontColor('rgba(255,255,255,0.4)')
                Text('请在上方搜索并添加城市')
                  .fontSize(13).fontColor('rgba(255,255,255,0.25)')
                  .margin({ top: 6 })
              }
              .width('100%')
              .padding(40)
            }
          }

          ListItem() {
            Column().height(24)
          }
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 4 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0d0d0d')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
