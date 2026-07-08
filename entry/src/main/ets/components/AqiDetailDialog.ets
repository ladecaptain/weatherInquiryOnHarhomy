/**
 * AQI 空气质量详情弹窗
 * 展示六项污染物分级柱状图 + 健康建议
 */
import { DetailPayload } from './DetailDialogs'
import { calculateAqi, AqiResult } from '../utils/AqiCalculator'

@CustomDialog
export struct AqiDetailDialog {
  controller: CustomDialogController
  @Link payload: DetailPayload

  private getAqiValue(): number {
    if (!this.payload.aqiData) return 0
    const apiAqi = Number(this.payload.aqiData.aqi)
    if (!isNaN(apiAqi) && apiAqi > 0) return apiAqi
    const result: AqiResult = calculateAqi(
      this.payload.aqiData.pm2p5, this.payload.aqiData.pm10,
      this.payload.aqiData.so2, this.payload.aqiData.no2,
      this.payload.aqiData.co, this.payload.aqiData.o3
    )
    return result.aqi
  }

  private getAqiColor(value: number): string {
    if (value <= 50) return '#00e676'
    if (value <= 100) return '#ffd600'
    if (value <= 150) return '#ff9100'
    if (value <= 200) return '#ff5252'
    if (value <= 300) return '#d500f9'
    return '#7b1fa2'
  }

  private getAqiCategory(value: number): string {
    if (value <= 50) return '优'
    if (value <= 100) return '良'
    if (value <= 150) return '轻度污染'
    if (value <= 200) return '中度污染'
    if (value <= 300) return '重度污染'
    return '严重污染'
  }

  private getHealthAdvice(value: number): string {
    if (value <= 50) return '空气质量令人满意，基本无空气污染，各类人群可正常活动。'
    if (value <= 100) return '空气质量可接受，某些污染物可能对极少数异常敏感人群健康有较弱影响。'
    if (value <= 150) return '易感人群症状有轻度加剧，健康人群出现刺激症状。建议减少户外活动。'
    if (value <= 200) return '进一步加剧易感人群症状，可能对健康人群心脏、呼吸系统有影响。避免户外活动。'
    if (value <= 300) return '心脏病和肺病患者症状显著加剧，运动耐受力降低。停止户外活动。'
    return '健康人群运动耐受力降低，有明显强烈症状。务必留在室内。'
  }

  private pollutantBar(label: string, value: string, unit: string, color: string): void {
  }

  @Builder
  PollutantItem(label: string, value: string, unit: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor('rgba(255,255,255,0.65)')
        .width(60)
      Blank()
      Text(value && value.length > 0 ? `${value} ${unit}` : '--')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#ffffff')
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor('rgba(255,255,255,0.04)')
    .borderRadius(10)
  }

  build() {
    Column() {
      // 标题栏 + X 关闭按钮
      Row() {
        Text('空气质量详情')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#ffffff')
        Blank()
        Button() { Image($r('sys.media.ohos_ic_public_close')).width(22).height(22).fillColor('#ffffff') }
          .width(38).height(38)
          .backgroundColor('rgba(255,255,255,0.10)')
          .borderRadius(19)
          .onClick(() => this.controller.close())
      }
      .width('100%')
      .padding({ left: 16, right: 8, top: 10, bottom: 16 })

      if (this.payload.aqiData !== null) {
        Column() {
          // AQI 大数值

          // AQI 大数值
          Text(`${this.getAqiValue()}`)
            .fontSize(56)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getAqiColor(this.getAqiValue()))
            .margin({ bottom: 4 })

          Text(this.getAqiCategory(this.getAqiValue()))
            .fontSize(16)
            .fontColor(this.getAqiColor(this.getAqiValue()))
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: 6 })

          if (this.payload.aqiData.primary && this.payload.aqiData.primary.length > 0) {
            Text(`首要污染物：${this.payload.aqiData.primary}`)
              .fontSize(12)
              .fontColor('rgba(255,255,255,0.40)')
              .margin({ bottom: 20 })
          }

          // 污染物详情
          Text('污染物详情')
            .fontSize(14)
            .fontColor('rgba(255,255,255,0.50)')
            .margin({ bottom: 10 })
            .alignSelf(ItemAlign.Start)

          Column({ space: 6 }) {
            this.PollutantItem('PM2.5', this.payload.aqiData.pm2p5, 'μg/m³')
            this.PollutantItem('PM10', this.payload.aqiData.pm10, 'μg/m³')
            this.PollutantItem('SO₂', this.payload.aqiData.so2, 'μg/m³')
            this.PollutantItem('NO₂', this.payload.aqiData.no2, 'μg/m³')
            this.PollutantItem('CO', this.payload.aqiData.co, 'mg/m³')
            this.PollutantItem('O₃', this.payload.aqiData.o3, 'μg/m³')
          }
          .width('100%')

          // 健康建议
          Column() {
            Text('💡 健康建议')
              .fontSize(13)
              .fontColor('rgba(255,255,255,0.50)')
              .margin({ bottom: 8 })

            Text(this.getHealthAdvice(this.getAqiValue()))
              .fontSize(13)
              .fontColor('rgba(255,255,255,0.70)')
              .lineHeight(20)
          }
          .width('100%')
          .padding(14)
          .backgroundColor('rgba(255,255,255,0.04)')
          .borderRadius(12)
          .margin({ top: 16 })
        }
        .width('100%')
      } else {
        Column() {
          Text('😔')
            .fontSize(40)
            .margin({ bottom: 12 })
          Text('AQI 数据不可用')
            .fontSize(16)
            .fontColor('rgba(255,255,255,0.50)')
          Text('可能需要付费 API 订阅')
            .fontSize(13)
            .fontColor('rgba(255,255,255,0.30)')
            .margin({ top: 4 })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 40, bottom: 40 })
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, bottom: 30 })
    .backgroundColor('#1C1C1E')
    .borderRadius({ topLeft: 20, topRight: 20 })
  }
}
