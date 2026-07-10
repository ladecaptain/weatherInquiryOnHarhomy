import { AirQualityData } from '../model/WeatherModel'
import { calculateAqi, AqiResult } from '../utils/AqiCalculator'

/**
 * 环境数据卡片组件
 * 2×2 网格：AQI、紫外线、湿度、降水
 * + 风力风向 独立整行（罗盘在右）
 * + 能见度 & 气压 横排等宽（气压上下加长）
 */
@Component
export struct EnvironmentCards {
  @Prop aqiData: AirQualityData | null = null
  @Prop isClearBg: boolean = false
  @Prop humidity: string = ''
  @Prop dew: string = ''
  @Prop uvIndex: string = ''
  @Prop windDir: string = ''
  @Prop windScale: string = ''
  @Prop windSpeed: string = ''
  @Prop wind360: string = ''
  @Prop visValue: string = ''
  @Prop pressure: string = ''
  @Prop pop: string = ''
  @Prop precip: string = ''
  @Prop tomorrowPrecip: string = ''
  onAqiClick?: () => void
  onUvClick?: () => void
  onHumidityClick?: () => void
  onWindClick?: () => void
  onVisClick?: () => void
  onPressureClick?: () => void
  onPrecipClick?: () => void

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
    this.drawWindCompass()
    this.drawPressureGauge(Number(this.pressure))
  }

  // 气压仪表盘 Canvas
  private pressureSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private pressureCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.pressureSettings)

  // 风力罗盘 Canvas
  private windCompassSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private windCompassCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.windCompassSettings)

  private drawPressureGauge(pVal: number): void {
    const ctx = this.pressureCtx
    const w = 130, h = 80
    const cx = w / 2, cy = h - 12, r = 54

    ctx.clearRect(0, 0, w, h)

    // 灰色弧底
    ctx.beginPath()
    ctx.arc(cx, cy, r, Math.PI, 0)
    ctx.strokeStyle = 'rgba(255,255,255,0.10)'
    ctx.lineWidth = 6
    ctx.stroke()

    if (isNaN(pVal)) return

    // 数值 → 角度 (950-1050 → 180°-360°)
    const t = Math.max(0, Math.min(1, (pVal - 950) / 100))
    const endAngle = Math.PI + t * Math.PI

    // 彩色弧
    const grad = ctx.createLinearGradient(0, cy - r, 0, cy + r)
    grad.addColorStop(0, '#AF52DE')
    grad.addColorStop(0.5, '#9B59B6')
    grad.addColorStop(1, '#7B2FBE')
    ctx.beginPath()
    ctx.arc(cx, cy, r, Math.PI, endAngle)
    ctx.strokeStyle = grad
    ctx.lineWidth = 6
    ctx.lineCap = 'round'
    ctx.stroke()
    ctx.lineCap = 'butt'

    // 指针
    const a = Math.PI + t * Math.PI
    const tipX = cx + r * Math.cos(a)
    const tipY = cy + r * Math.sin(a)
    ctx.beginPath()
    ctx.moveTo(cx, cy)
    ctx.lineTo(tipX, tipY)
    ctx.strokeStyle = '#ffffff'
    ctx.lineWidth = 2
    ctx.stroke()
  }

  private drawWindCompass(): void {
    const w = 300; const h = 300
    const cx = w / 2; const cy = h / 2
    const outerR = 140

    const degToCanvasRad = (deg: number): number => ((deg + 270) % 360) * Math.PI / 180

    const ctx = this.windCompassCtx
    ctx.clearRect(0, 0, w, h)

    // Outer ring
    ctx.beginPath()
    ctx.arc(cx, cy, outerR, 0, Math.PI * 2)
    ctx.strokeStyle = 'rgba(255,255,255,0.14)'
    ctx.lineWidth = 1.5
    ctx.stroke()

    // Tick marks every 10° with major at 45°
    for (let deg = 0; deg < 360; deg += 10) {
      const rad = degToCanvasRad(deg)
      const isMajor = deg % 45 === 0
      const isHalf = deg % 15 === 0
      const tickOuter = outerR - 1
      let tickInner: number
      if (isMajor) {
        tickInner = outerR - 28
      } else if (isHalf) {
        tickInner = outerR - 18
      } else {
        tickInner = outerR - 12
      }
      ctx.beginPath()
      ctx.moveTo(cx + tickInner * Math.cos(rad), cy + tickInner * Math.sin(rad))
      ctx.lineTo(cx + tickOuter * Math.cos(rad), cy + tickOuter * Math.sin(rad))
      ctx.strokeStyle = isMajor
        ? 'rgba(255,255,255,0.55)'
        : (isHalf ? 'rgba(255,255,255,0.22)' : 'rgba(255,255,255,0.10)')
      ctx.lineWidth = isMajor ? 1.5 : 0.8
      ctx.stroke()
    }

    // Direction labels (larger fonts than before)
    const directions: [string, number][] = [
      ['北', 0], ['东北', 45], ['东', 90], ['东南', 135],
      ['南', 180], ['西南', 225], ['西', 270], ['西北', 315]
    ]
    for (const dirItem of directions) {
      const label = dirItem[0]
      const deg = dirItem[1]
      const rad = degToCanvasRad(deg)
      const lx = cx + (outerR - 55) * Math.cos(rad)
      const ly = cy + (outerR - 55) * Math.sin(rad)
      ctx.fillStyle = 'rgba(255,255,255,0.80)'
      ctx.font = 'bold 40px sans-serif'
      ctx.textAlign = 'center'
      ctx.textBaseline = 'middle'
      ctx.fillText(label, lx, ly)
    }

    // Wind direction arrow
    const windDeg = parseFloat(this.wind360)
    const arrowDeg = isNaN(windDeg) ? 0 : (windDeg + 180) % 360
    const arrowRad = degToCanvasRad(arrowDeg)
    const arrowLen = outerR - 65

    const ax = cx + arrowLen * Math.cos(arrowRad)
    const ay = cy + arrowLen * Math.sin(arrowRad)

    // Arrow body
    ctx.beginPath()
    ctx.moveTo(cx, cy)
    ctx.lineTo(ax, ay)
    ctx.strokeStyle = '#5AC8FA'
    ctx.lineWidth = 4
    ctx.lineCap = 'round'
    ctx.stroke()
    ctx.lineCap = 'butt'

    // Arrow head
    const headLen = 18
    const headHW = 11
    const sx = ax - headLen * Math.cos(arrowRad)
    const sy = ay - headLen * Math.sin(arrowRad)
    const perp = arrowRad + Math.PI / 2
    ctx.beginPath()
    ctx.moveTo(ax, ay)
    ctx.lineTo(sx + headHW * Math.cos(perp), sy + headHW * Math.sin(perp))
    ctx.lineTo(sx - headHW * Math.cos(perp), sy - headHW * Math.sin(perp))
    ctx.closePath()
    ctx.fillStyle = '#5AC8FA'
    ctx.fill()

    // Center dot
    ctx.beginPath()
    ctx.arc(cx, cy, 7, 0, Math.PI * 2)
    ctx.fillStyle = '#5AC8FA'
    ctx.fill()
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
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('rgba(255,255,255,0.90)')
        Blank()
      }
      .width('100%')
      .padding({ left: 4, right: 4, bottom: 10 })

      // ── 2×2 网格：AQI / 紫外线 / 湿度 / 降水 ──
      Grid() {
        GridItem() { this.AqiCell() }.onClick(() => { if (this.onAqiClick) this.onAqiClick() })
        GridItem() { this.UvCell() }.onClick(() => { if (this.onUvClick) this.onUvClick() })
        GridItem() { this.HumidityCell() }.onClick(() => { if (this.onHumidityClick) this.onHumidityClick() })
        GridItem() { this.PrecipCell() }.onClick(() => { if (this.onPrecipClick) this.onPrecipClick() })
      }
      .columnsTemplate('1fr 1fr')
      .rowsTemplate('1fr 1fr')
      .columnsGap(10)
      .rowsGap(10)
      .width('100%')
      .height(220)

      // ── 风力风向 独立整行（标题 + 信息 + 罗盘在右） ──
      Column() {
        // 标题
        Text('风力风向')
          .fontSize(13)
          .fontColor('rgba(255,255,255,0.50)')
          .alignSelf(ItemAlign.Start)
          .margin({ left: 10, top: 8 })

        // 大型风力罗盘（居中）
        Canvas(this.windCompassCtx)
          .width(300).height(300)
          .alignSelf(ItemAlign.Center)
          .onReady(() => { this.drawWindCompass() })

        // 底部文字信息
        Row({ space: 8 }) {
          Text(this.windDir && this.windDir.length > 0 ? this.windDir : '--')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#5AC8FA')
          Text(this.windScale && this.windScale.length > 0 ? `${this.windScale}级` : '')
            .fontSize(16)
            .fontColor('#5AC8FA')
            .fontWeight(FontWeight.Medium)
          Text(this.windSpeed && this.windSpeed.length > 0 ? `风速 ${this.windSpeed} km/h` : '')
            .fontSize(13)
            .fontColor('rgba(255,255,255,0.50)')
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ left: 10, right: 10, bottom: 10 })
      }
      .width('100%')
      .padding({ top: 4, bottom: 4 })
      .backgroundColor(this.isClearBg ? 'rgba(120,185,230,0.28)' : 'rgba(0,0,0,0.20)')
      .borderRadius(12)
      .margin({ top: 10 })
      .onClick(() => { if (this.onWindClick) this.onWindClick() })

      // ── 能见度 & 气压 横排等宽、气压纵向加长 ──
      Row({ space: 10 }) {
        // 能见度
        Column() {
          Text('能见度')
            .fontSize(13)
            .fontColor('rgba(255,255,255,0.50)')
            .margin({ bottom: 6 })

          Text(this.visValue && this.visValue.length > 0 ? `${this.visValue} km` : '--')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getVisibilityColor(Number(this.visValue)))
            .margin({ bottom: 2 })

          Text(this.visValue && this.visValue.length > 0 ? this.getVisibilityDesc(Number(this.visValue)) : '')
            .fontSize(13)
            .fontColor(this.getVisibilityColor(Number(this.visValue)))
        }
        .width('50%')
        .height(110)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(this.isClearBg ? 'rgba(120,185,230,0.28)' : 'rgba(0,0,0,0.20)')
        .borderRadius(12)
        .onClick(() => { if (this.onVisClick) this.onVisClick() })

        // 气压 — 上下加长
        Column() {
          Text('气压')
            .fontSize(13)
            .fontColor('rgba(255,255,255,0.50)')
            .margin({ bottom: 6 })

          Stack() {
            Canvas(this.pressureCtx)
              .width(130).height(80)
              .onReady(() => { this.drawPressureGauge(Number(this.pressure)) })

            Column() {
              Text(this.pressure && this.pressure.length > 0 ? `${this.pressure}` : '--')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#AF52DE')
              Text('hPa')
                .fontSize(12)
                .fontColor('rgba(255,255,255,0.50)')
            }
          }
          .margin({ bottom: 2 })

          Text(this.pressure && this.pressure.length > 0 ? this.getPressureDesc(Number(this.pressure)) : '')
             .fontSize(13)
            .fontColor('#AF52DE')
        }
        .width('50%')
        .height(110)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(this.isClearBg ? 'rgba(120,185,230,0.28)' : 'rgba(0,0,0,0.20)')
        .borderRadius(12)
        .onClick(() => { if (this.onPressureClick) this.onPressureClick() })
      }
      .width('100%')
      .margin({ top: 10 })
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.isClearBg ? 'rgba(120,185,230,0.35)' : 'rgba(0,0,0,0.30)')
    .backdropBlur(20)
    .borderRadius(16)
    .margin({ left: 12, right: 12, top: 10 })
  }

  // ═══════════ @Builder 卡片 ═══════════

  @Builder AqiCell() {
    Column() {
      Text('AQI').fontSize(14).fontColor('rgba(255,255,255,0.60)').margin({ bottom: 4 })
      Text(this.computedAqiValue).fontSize(30).fontWeight(FontWeight.Bold).fontColor(this.computedAqiColor).margin({ bottom: 2 })
      Text(this.computedAqiCategory).fontSize(14).fontColor(this.computedAqiColor).fontWeight(FontWeight.Medium).margin({ bottom: 4 })
      Text(this.computedAqiPrimary).fontSize(12).fontColor('rgba(255,255,255,0.50)')
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .backgroundColor(this.isClearBg ? 'rgba(120,185,230,0.28)' : 'rgba(0,0,0,0.20)').borderRadius(12)
  }

  @Builder UvCell() {
    Column() {
      Text('紫外线').fontSize(14).fontColor('rgba(255,255,255,0.60)').margin({ bottom: 4 })
      Text(this.uvIndex && this.uvIndex.length > 0 ? `${this.uvIndex} | ${this.getUvLevel(Number(this.uvIndex))}` : '--')
        .fontSize(16).fontWeight(FontWeight.Bold)
        .fontColor(this.uvIndex && this.uvIndex.length > 0 ? this.getUvColor(Number(this.uvIndex)) : 'rgba(255,255,255,0.25)')
        .margin({ bottom: 4 })

      Stack() {
        Row().width('70%').height(4).borderRadius(2)
          .linearGradient({ direction: GradientDirection.Right,
            colors: [['#00e676', 0], ['#ffd600', 0.25], ['#ff9100', 0.45], ['#ff5252', 0.7], ['#d500f9', 1]] })

        if (this.uvIndex && this.uvIndex.length > 0) {
          Circle().width(10).height(10).fill(this.getUvColor(Number(this.uvIndex)))
            .stroke(Color.White).strokeWidth(2)
            .position({ x: `${Math.min(Number(this.uvIndex) / 12 * 70, 70)}%`, y: -3 })
            .translate({ x: -5 })
        }
      }.width('70%').height(10).margin({ top: 2 })

      if (this.uvIndex && Number(this.uvIndex) >= 3) {
        Text('注意防晒').fontSize(13).fontColor(this.getUvColor(Number(this.uvIndex))).margin({ top: 4 })
      }
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .backgroundColor(this.isClearBg ? 'rgba(120,185,230,0.28)' : 'rgba(0,0,0,0.20)').borderRadius(12)
  }

  @Builder HumidityCell() {
    Column() {
      Text('湿度').fontSize(14).fontColor('rgba(255,255,255,0.60)').margin({ bottom: 4 })
      Text(this.humidity && this.humidity.length > 0 ? `${this.humidity}%` : '--')
        .fontSize(30).fontWeight(FontWeight.Bold)
        .fontColor(this.humidity && this.humidity.length > 0 ? '#9B59B6' : 'rgba(255,255,255,0.25)')
        .margin({ bottom: 2 })
      Text(this.humidity && this.humidity.length > 0 ? this.getHumidityDesc(Number(this.humidity)) : '')
        .fontSize(14).fontColor('#9B59B6').fontWeight(FontWeight.Medium)
      Text(this.dew && this.dew.length > 0 ? `露点温度 ${this.dew}°` : '')
        .fontSize(12).fontColor('rgba(255,255,255,0.50)').margin({ top: 2 })
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .backgroundColor(this.isClearBg ? 'rgba(120,185,230,0.28)' : 'rgba(0,0,0,0.20)').borderRadius(12)
  }

  @Builder PrecipCell() {
    Column() {
      Text('降水').fontSize(14).fontColor('rgba(255,255,255,0.60)').margin({ bottom: 4 })

      Text(this.precip && this.precip.length > 0 ? `${this.precip}mm` : '0mm')
        .fontSize(22).fontWeight(FontWeight.Bold)
        .fontColor(this.getPrecipColor(this.precip && this.precip.length > 0 ? parseFloat(this.precip) : 0))
        .margin({ bottom: 2 })

      Text(`今天`).fontSize(12).fontColor('rgba(255,255,255,0.50)')

      if (this.pop && this.pop.length > 0 && parseFloat(this.pop) > 0) {
        Text(`降水概率 ${this.pop}%`).fontSize(13).fontColor('rgba(255,255,255,0.50)').margin({ top: 2 })
      }

      if (this.tomorrowPrecip && this.tomorrowPrecip.length > 0 && this.tomorrowPrecip !== '0.0') {
        Text(`明天预计 ${this.tomorrowPrecip}mm`).fontSize(13).fontColor('rgba(255,255,255,0.50)').margin({ top: 2 })
      }
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .backgroundColor(this.isClearBg ? 'rgba(120,185,230,0.28)' : 'rgba(0,0,0,0.20)').borderRadius(12)
  }

  // ═══════════ 辅助方法 ═══════════

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
    if (uv <= 7) return '强'
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

  getPopColor(pop: number): string {
    if (isNaN(pop)) return 'rgba(255,255,255,0.70)'
    if (pop >= 80) return '#0A84FF'
    if (pop >= 50) return '#5AC8FA'
    return 'rgba(255,255,255,0.70)'
  }

  getPrecipColor(precip: number): string {
    if (isNaN(precip)) return 'rgba(255,255,255,0.70)'
    if (precip >= 10) return '#0A84FF'
    if (precip >= 5) return '#5AC8FA'
    if (precip > 0) return '#AF52DE'
    return 'rgba(255,255,255,0.50)'
  }
}
