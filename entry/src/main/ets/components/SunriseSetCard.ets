import { ForecastDay } from '../model/WeatherModel'

@Component
export struct SunriseSetCard {
  @Prop sunrise: string = ''
  @Prop sunset: string = ''
  @Prop forecastDays: ForecastDay[] = []
  @Prop isClearBg: boolean = false
  onCardClick?: () => void

  private canvasSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.canvasSettings)
  @State canvasWidth: number = 360
  @State canvasHeight: number = 140

  private timeToMinutes(t: string): number {
    if (!t) return -1
    const parts = t.split(':')
    if (parts.length < 2) return -1
    return parseInt(parts[0]) * 60 + parseInt(parts[1])
  }

  private timeToX(t: string, w: number, pl: number, pr: number): number {
    const m = this.timeToMinutes(t)
    if (m < 0) return pl
    return pl + ((m / 1440) * (w - pl - pr))
  }

  private drawSunCurve(): void {
    const w = this.canvasWidth; const h = this.canvasHeight
    if (w <= 0 || h <= 0) return
    const ctx = this.ctx
    ctx.clearRect(0, 0, w, h)

    const pl = 20; const pr = 20; const pt = 10; const pb = 30
    const cw = w - pl - pr; const ch = h - pt - pb

    const srMin = this.timeToMinutes(this.sunrise)
    const ssMin = this.timeToMinutes(this.sunset)
    if (srMin < 0 || ssMin < 0) return

    const srX = pl + (srMin / 1440) * cw
    const ssX = pl + (ssMin / 1440) * cw
    const peakX = (srX + ssX) / 2
    const peakY = pt
    const baseY = pt + ch

    const now = new Date()
    const nowMin = now.getHours() * 60 + now.getMinutes()
    const nowX = pl + (nowMin / 1440) * cw

    ctx.strokeStyle = 'rgba(255,255,255,0.10)'; ctx.lineWidth = 1
    ctx.beginPath(); ctx.moveTo(pl, baseY); ctx.lineTo(w - pr, baseY); ctx.stroke()

    ctx.fillStyle = 'rgba(255,255,255,0.20)'; ctx.font = '28px sans-serif'
    ctx.fillText('0', pl - 4, baseY + 18)
    ctx.fillText('6', pl + (6 / 24) * cw - 4, baseY + 18)
    ctx.fillText('12', pl + (12 / 24) * cw - 6, baseY + 18)
    ctx.fillText('18', pl + (18 / 24) * cw - 6, baseY + 18)
    ctx.fillText('24', w - pr - 8, baseY + 18)

    const grad = ctx.createLinearGradient(srX, peakY, ssX, baseY)
    grad.addColorStop(0, 'rgba(255,215,0,0.25)')
    grad.addColorStop(0.5, 'rgba(255,107,53,0.15)')
    grad.addColorStop(1, 'rgba(255,107,53,0.02)')
    ctx.beginPath()
    ctx.moveTo(srX, baseY)
    ctx.quadraticCurveTo(peakX, peakY, ssX, baseY)
    ctx.closePath()
    ctx.fillStyle = grad; ctx.fill()

    ctx.strokeStyle = '#FF9500'; ctx.lineWidth = 2.5; ctx.lineCap = 'round'
    ctx.beginPath()
    ctx.moveTo(srX, baseY)
    ctx.quadraticCurveTo(peakX, peakY, ssX, baseY)
    ctx.stroke()

    if (nowMin >= srMin && nowMin <= ssMin) {
      const t = (nowMin - srMin) / (ssMin - srMin)
      const sunX = srX + t * (ssX - srX)
      const sunY = baseY - 4 * t * (1 - t) * (baseY - peakY)

      ctx.strokeStyle = 'rgba(255,215,0,0.40)'; ctx.lineWidth = 1.5; ctx.setLineDash([4, 4])
      ctx.beginPath(); ctx.moveTo(sunX, sunY); ctx.lineTo(sunX, baseY); ctx.stroke()
      ctx.setLineDash([])

      ctx.fillStyle = '#FF9500'; ctx.beginPath(); ctx.arc(sunX, sunY, 8, 0, Math.PI * 2); ctx.fill()
      ctx.fillStyle = '#ffffff'; ctx.beginPath(); ctx.arc(sunX, sunY, 4, 0, Math.PI * 2); ctx.fill()
    }

    ctx.fillStyle = '#FF9500'; ctx.font = '28px sans-serif'; ctx.textAlign = 'center'
    ctx.fillText(this.sunrise, srX, baseY - 6)
    ctx.fillStyle = '#FF6B35'
    ctx.fillText(this.sunset, ssX, baseY - 6)
    ctx.textAlign = 'start'
  }

  build() {
    Column() {
      Row() {
        Text('日出日落')
          .fontSize(14)
          .fontColor('rgba(255,255,255,0.60)')
          .margin({ bottom: 6 })
        Blank()
        Image($r('sys.media.ohos_ic_public_arrow_right'))
          .width(12).height(12).fillColor('rgba(255,255,255,0.35)')
      }.width('100%')

      Row({ space: 16 }) {
        Column() {
          Text(this.sunrise || '--:--')
            .fontSize(22).fontWeight(FontWeight.Bold).fontColor('#FF9500')
          Text('日出').fontSize(12).fontColor('rgba(255,255,255,0.50)').margin({ top: 2 })
        }.alignItems(HorizontalAlign.Center).layoutWeight(1)

        Column() {
          Text(this.sunset || '--:--')
            .fontSize(22).fontWeight(FontWeight.Bold).fontColor('#FF6B35')
          Text('日落').fontSize(12).fontColor('rgba(255,255,255,0.50)').margin({ top: 2 })
        }.alignItems(HorizontalAlign.Center).layoutWeight(1)
      }.width('100%').margin({ bottom: 8 })

      Canvas(this.ctx)
        .width('100%').height(140)
        .onAreaChange((_old: Area, nv: Area) => {
          const nw = nv.width as number; const nh = nv.height as number
          if (nw > 0) this.canvasWidth = nw; if (nh > 0) this.canvasHeight = nh
        })
        .onReady(() => { this.drawSunCurve() })
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.isClearBg ? 'rgba(120,185,230,0.35)' : 'rgba(0,0,0,0.30)')
    .backdropBlur(20)
    .borderRadius(16)
    .margin({ left: 12, right: 12, top: 10 })
    .onClick(() => { if (this.onCardClick) this.onCardClick() })
  }
}
