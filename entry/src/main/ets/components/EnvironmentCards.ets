import { AirQualityData } from '../model/WeatherModel'
import { calculateAqi, AqiResult } from '../utils/AqiCalculator'

/**
 * 环境数据卡片组件
 * 2×2 网格展示 AQI、紫外线、湿度、风力风向
 * + 能见度 & 气压横排
 */
@Component
export struct EnvironmentCards {
  @Prop aqiData: AirQualityData | null = null
  @Prop humidity: string = ''
  @Prop uvIndex: string = ''
  @Prop windDir: string = ''
  @Prop windScale: string = ''
  @Prop windSpeed: string = ''
  @Prop visValue: string = ''
  @Prop pressure: string = ''

  /** 预计算 AQI 展示值（API 优先，无则从污染物反推） */
  private computedAqiValue: string = ''
  private computedAqiCategory: string = ''
  private computedAqiPrimary: string = ''
  private computedAqiColor: string = 'rgba(255,255,255,0.2)'
  private aqiCalculated: boolean = false

  aboutToAppear(): void {
    this.recalcAqi()
  }

  onPropsChanged(): void {
    this.recalcAqi()
  }

  private recalcAqi(): void {
    if (this.aqiData === null) {
      this.computedAqiValue = '--'
      this.computedAqiCategory = '空气质量不可用'
      this.computedAqiPrimary = 'API需付费订阅'
      this.computedAqiColor = 'rgba(255,255,255,0.2)'
      this.aqiCalculated = true
      return
    }

    const apiAqi = Number(this.aqiData.aqi)
    if (!isNaN(apiAqi) && apiAqi > 0) {
      this.computedAqiValue = this.aqiData.aqi
      this.computedAqiCategory = this.aqiData.category
      this.computedAqiPrimary = this.aqiData.primary ? `首要: ${this.aqiData.primary}` : ''
      this.computedAqiColor = this.getAqiColorByNumber(apiAqi)
    } else {
      const result: AqiResult = calculateAqi(
        this.aqiData.pm2p5, this.aqiData.pm10,
        this.aqiData.so2, this.aqiData.no2,
        this.aqiData.co, this.aqiData.o3
      )
      this.computedAqiValue = `${result.aqi}`
      this.computedAqiCategory = result.category
      this.computedAqiPrimary = `首要: ${result.primaryPollutant}`
      this.computedAqiColor = this.getAqiColorByNumber(result.aqi)
    }
    this.aqiCalculated = true
  }

  build() {
    Column() {
      // 标题行
      Row() {
        Text('环境数据')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('rgba(255,255,255,0.80)')
        Blank()
      }
      .width('100%')
      .padding({ left: 4, right: 4, bottom: 10 })

      // 2×2 网格
      Grid() {
        GridItem() { this.AqiCard() }
        GridItem() { this.UvCard() }
        GridItem() { this.HumidityCard() }
        GridItem() { this.WindCard() }
      }
      .columnsTemplate('1fr 1fr')
      .rowsTemplate('1fr 1fr')
      .columnsGap(10)
      .rowsGap(10)
      .width('100%')
      .height(220)

      // 能见度 & 气压 横排
      Row({ space: 10 }) {
        // 能见度
        Column() {
          Text('能见度')
            .fontSize(12)
            .fontColor('rgba(255,255,255,0.40)')
            .margin({ bottom: 4 })

          Text(this.visValue && this.visValue.length > 0 ? `${this.visValue} km` : '--')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getVisibilityColor(Number(this.visValue)))
            .margin({ bottom: 2 })

          Text(this.visValue && this.visValue.length > 0 ? this.getVisibilityDesc(Number(this.visValue)) : '')
            .fontSize(11)
            .fontColor(this.getVisibilityColor(Number(this.visValue)))
        }
        .width('50%')
        .height(88)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('rgba(255,255,255,0.05)')
        .borderRadius(12)

        // 气压
        Column() {
          Text('气压')
            .fontSize(12)
            .fontColor('rgba(255,255,255,0.40)')
            .margin({ bottom: 4 })

          Text(this.pressure && this.pressure.length > 0 ? `${this.pressure} hPa` : '--')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#74b9ff')
            .margin({ bottom: 2 })

          Text(this.pressure && this.pressure.length > 0 ? this.getPressureDesc(Number(this.pressure)) : '')
            .fontSize(11)
            .fontColor('#74b9ff')
        }
        .width('50%')
        .height(88)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('rgba(255,255,255,0.05)')
        .borderRadius(12)
      }
      .width('100%')
      .margin({ top: 10 })
    }
    .width('100%')
    .padding(14)
    .backgroundColor('rgba(255,255,255,0.06)')
    .backdropBlur(20)
    .borderRadius(16)
    .margin({ left: 12, right: 12, top: 10 })
  }

  /** AQI 卡片（使用预计算值，避免 Builder 内逻辑） */
  @Builder
  AqiCard() {
    Column() {
      Text('AQI')
        .fontSize(12)
        .fontColor('rgba(255,255,255,0.40)')
        .margin({ bottom: 4 })

      Text(this.computedAqiValue)
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.computedAqiColor)
        .margin({ bottom: 2 })

      Text(this.computedAqiCategory)
        .fontSize(12)
        .fontColor(this.computedAqiColor)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 4 })

      Text(this.computedAqiPrimary)
        .fontSize(10)
        .fontColor('rgba(255,255,255,0.3)')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('rgba(255,255,255,0.05)')
    .borderRadius(12)
  }

  /** 紫外线卡片 */
  @Builder
  UvCard() {
    Column() {
      Text('紫外线')
        .fontSize(12)
        .fontColor('rgba(255,255,255,0.40)')
        .margin({ bottom: 4 })

      Text(this.uvIndex && this.uvIndex.length > 0 ? this.uvIndex : '--')
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.uvIndex && this.uvIndex.length > 0 ? this.getUvColor(Number(this.uvIndex)) : 'rgba(255,255,255,0.25)')
        .margin({ bottom: 2 })

      Text(this.uvIndex && this.uvIndex.length > 0 ? this.getUvLevel(Number(this.uvIndex)) : '')
        .fontSize(12)
        .fontColor(this.uvIndex && this.uvIndex.length > 0 ? this.getUvColor(Number(this.uvIndex)) : 'rgba(255,255,255,0.25)')
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('rgba(255,255,255,0.05)')
    .borderRadius(12)
  }

  /** 湿度卡片 */
  @Builder
  HumidityCard() {
    Column() {
      Text('湿度')
        .fontSize(12)
        .fontColor('rgba(255,255,255,0.40)')
        .margin({ bottom: 4 })

      Text(this.humidity && this.humidity.length > 0 ? `${this.humidity}%` : '--')
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.humidity && this.humidity.length > 0 ? '#4ecdc4' : 'rgba(255,255,255,0.25)')
        .margin({ bottom: 2 })

      Text(this.humidity && this.humidity.length > 0 ? this.getHumidityDesc(Number(this.humidity)) : '')
        .fontSize(12)
        .fontColor('#4ecdc4')
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('rgba(255,255,255,0.05)')
    .borderRadius(12)
  }

  /** 风力风向卡片 */
  @Builder
  WindCard() {
    Column() {
      Text('风力风向')
        .fontSize(12)
        .fontColor('rgba(255,255,255,0.40)')
        .margin({ bottom: 4 })

      Text(this.windDir && this.windDir.length > 0 ? this.windDir : '--')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.windDir && this.windDir.length > 0 ? '#a29bfe' : 'rgba(255,255,255,0.25)')
        .margin({ bottom: 2 })

      Text(this.windDir && this.windDir.length > 0 ? `${this.windScale}级${this.windSpeed ? ' · ' + this.windSpeed + 'km/h' : ''}` : '')
        .fontSize(11)
        .fontColor('#a29bfe')
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('rgba(255,255,255,0.05)')
    .borderRadius(12)
  }

  // ─── 辅助方法 ──────────────────────────────────────

  getAqiColorByNumber(aqi: number): string {
    if (aqi <= 50) return '#00e676'
    if (aqi <= 100) return '#ffd600'
    if (aqi <= 150) return '#ff9100'
    if (aqi <= 200) return '#ff5252'
    if (aqi <= 300) return '#d500f9'
    return '#7b1fa2'
  }

  getUvColor(uv: number): string {
    if (uv <= 2) return '#00e676'
    if (uv <= 5) return '#ffd600'
    if (uv <= 7) return '#ff9100'
    if (uv <= 10) return '#ff5252'
    return '#d500f9'
  }

  getUvLevel(uv: number): string {
    if (uv <= 2) return '最弱'
    if (uv <= 5) return '中等'
    if (uv <= 7) return '较强'
    if (uv <= 10) return '很强'
    return '极强'
  }

  getHumidityDesc(humidity: number): string {
    if (humidity < 30) return '干燥'
    if (humidity < 60) return '舒适'
    if (humidity < 80) return '潮湿'
    return '非常潮湿'
  }

  getVisibilityColor(vis: number): string {
    if (isNaN(vis)) return 'rgba(255,255,255,0.25)'
    if (vis >= 20) return '#00e676'
    if (vis >= 10) return '#ffd600'
    if (vis >= 5) return '#ff9100'
    if (vis >= 1) return '#ff5252'
    return '#d500f9'
  }

  getVisibilityDesc(vis: number): string {
    if (isNaN(vis)) return ''
    if (vis >= 20) return '极好'
    if (vis >= 10) return '良好'
    if (vis >= 5) return '一般'
    if (vis >= 1) return '较差'
    return '很差'
  }

  getPressureDesc(pressure: number): string {
    if (isNaN(pressure)) return ''
    if (pressure > 1025) return '偏高'
    if (pressure < 1005) return '偏低'
    return '正常'
  }
}
