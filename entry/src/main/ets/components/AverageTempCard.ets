import { formatTempWithUnit } from '../services/TemperatureService'

@Component
export struct AverageTempCard {
  @Prop tempMax: string = ''
  @Prop tempMin: string = ''
  @Prop currentTemp: string = ''
  @Prop isClearBg: boolean = false
  @StorageProp('tempUnit') tempUnit: string = '°C'
  onCardClick?: () => void

  private canvasSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.canvasSettings)

  private getAvgTemp(): number {
    const max = parseFloat(this.tempMax)
    const min = parseFloat(this.tempMin)
    if (isNaN(max) || isNaN(min)) return NaN
    return (max + min) / 2
  }

  private getDeviation(): string {
    const avg = this.getAvgTemp()
    const cur = parseFloat(this.currentTemp)
    if (isNaN(avg) || isNaN(cur)) return ''
    const diff = cur - avg
    if (Math.abs(diff) < 0.5) return '±0°'
    return diff > 0 ? `+${Math.round(diff)}°` : `${Math.round(diff)}°`
  }

  private getDeviationDesc(): string {
    const avg = this.getAvgTemp()
    const cur = parseFloat(this.currentTemp)
    if (isNaN(avg) || isNaN(cur)) return ''
    const diff = cur - avg
    if (Math.abs(diff) < 0.5) return '接近均值'
    return diff > 0 ? '高于均值' : '低于均值'
  }

  private getDeviationColor(): string {
    const diff = parseFloat(this.getDeviation())
    if (isNaN(diff)) return 'rgba(255,255,255,0.25)'
    if (Math.abs(diff) < 0.5) return '#ffffff'
    return diff > 0 ? '#FF9500' : '#5AC8FA'
  }

  private drawMiniChart(): void {
    const ctx = this.ctx
    const w = 60; const h = 36
    ctx.clearRect(0, 0, w, h)

    const max = parseFloat(this.tempMax)
    const min = parseFloat(this.tempMin)
    const cur = parseFloat(this.currentTemp)
    if (isNaN(max) || isNaN(min)) return

    const range = max - min
    if (range <= 0) return

    const pts: number[] = [min, (min + max) / 2 * 0.3 + min * 0.7, (min + max) / 2, (min + max) / 2 * 0.7 + max * 0.3, max]
    const toY = (v: number) => h - 4 - ((v - min) / range) * (h - 8)

    const grad = ctx.createLinearGradient(0, 0, 0, h)
    grad.addColorStop(0, 'rgba(255,107,53,0.30)')
    grad.addColorStop(1, 'rgba(79,195,247,0.05)')
    ctx.beginPath()
    ctx.moveTo(0, h)
    for (let i = 0; i < pts.length; i++) {
      ctx.lineTo((w / (pts.length - 1)) * i, toY(pts[i]))
    }
    ctx.lineTo(w, h); ctx.closePath()
    ctx.fillStyle = grad; ctx.fill()

    ctx.strokeStyle = 'rgba(255,255,255,0.40)'; ctx.lineWidth = 1.5; ctx.lineJoin = 'round'
    ctx.beginPath()
    for (let i = 0; i < pts.length; i++) {
      const x = (w / (pts.length - 1)) * i; const y = toY(pts[i])
      if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
    }
    ctx.stroke()

    if (!isNaN(cur)) {
      const curY = toY(cur)
      ctx.fillStyle = this.getDeviationColor(); ctx.beginPath(); ctx.arc(w * 0.8, curY, 3, 0, Math.PI * 2); ctx.fill()
    }
  }

  build() {
    Row() {
      Column() {
        Text('平均温度')
          .fontSize(14)
          .fontColor('rgba(255,255,255,0.60)')
          .margin({ bottom: 4 })

        Row({ space: 6 }) {
          Text(this.getDeviation())
            .fontSize(40)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getDeviationColor())

          Column() {
              Text(this.getDeviationDesc())
                .fontSize(13)
                .fontColor(this.getDeviationColor())
              .fontWeight(FontWeight.Medium)
          }.alignItems(HorizontalAlign.Start)
        }

          Row({ space: 12 }) {
            Text(`最高 ${this.tempMax || '--'}°`)
              .fontSize(13)
              .fontColor('#FF9500')
            Text(`最低 ${this.tempMin || '--'}°`)
              .fontSize(13)
              .fontColor('#5AC8FA')
            Text(`日均 ${isNaN(this.getAvgTemp()) ? '--' : Math.round(this.getAvgTemp())}°`)
              .fontSize(13)
              .fontColor('rgba(255,255,255,0.55)')
          }
        .margin({ top: 6 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Canvas(this.ctx)
        .width(60).height(36)
        .onReady(() => { this.drawMiniChart() })
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.isClearBg ? 'rgba(120,185,230,0.35)' : 'rgba(0,0,0,0.30)')
    .backdropBlur(20)
    .borderRadius(16)
    .margin({ left: 12, right: 12, top: 10 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => { if (this.onCardClick) this.onCardClick() })
  }
}
