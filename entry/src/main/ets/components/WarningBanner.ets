import { WarningItem } from '../model/WeatherModel'

/**
 * 天气预警横幅组件
 * 四级颜色：蓝 / 黄 / 橙 / 红，可展开查看详情
 */
@Component
export struct WarningBanner {
  @Prop warnings: WarningItem[] = []
  @State isExpanded: boolean = false

  /** 根据预警等级获取背景色 */
  private getLevelColor(level: string): string {
    if (level.includes('红')) {
      return '#D32F2F'
    }
    if (level.includes('橙')) {
      return '#E65100'
    }
    if (level.includes('黄')) {
      return '#F9A825'
    }
    return '#1976D2'
  }

  /** 获取预警等级图标 */
  private getLevelIcon(level: string): string {
    if (level.includes('红')) {
      return '🔴'
    }
    if (level.includes('橙')) {
      return '🟠'
    }
    if (level.includes('黄')) {
      return '🟡'
    }
    return '🔵'
  }

  build() {
    Column() {
      if (this.warnings.length === 0) {
        Text('暂无预警')
          .fontSize(14)
          .fontColor('rgba(255,255,255,0.50)')
          .width('100%')
          .padding({ left: 14, right: 14, top: 12, bottom: 12 })
      } else {
      // 折叠状态：显示第一条预警概要
      Row({ space: 8 }) {
        Text(this.getLevelIcon(this.warnings[0].level))
          .fontSize(16)

        Text(this.warnings[0].title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#ffffff')
          .layoutWeight(1)
          .maxLines(1)

        Text(this.warnings.length > 1 ? `${this.warnings.length}条` : '')
          .fontSize(11)
          .fontColor('rgba(255,255,255,0.6)')

        Image($r('sys.media.ohos_ic_public_arrow_down'))
          .width(16).height(16)
          .fillColor('#ffffff')
          .rotate({ angle: this.isExpanded ? 180 : 0 })
          .animation({ duration: 200 })
      }
      .width('100%')
      .height(42)
      .padding({ left: 14, right: 14 })
      .backgroundColor(this.getLevelColor(this.warnings[0].level))
      .borderRadius(this.isExpanded ? { topLeft: 10, topRight: 10 } : 10)
      .onClick(() => {
        this.isExpanded = !this.isExpanded
      })

      // 展开状态：显示所有预警详情
      if (this.isExpanded && this.warnings.length > 0) {
        Column() {
          ForEach(this.warnings, (item: WarningItem, index: number) => {
            Column() {
              if (index > 0) {
                Divider()
                  .height(0.5)
                  .color('rgba(255,255,255,0.15)')
              }

              Column({ space: 4 }) {
                Row({ space: 6 }) {
                  Text(this.getLevelIcon(item.level)).fontSize(14)
                  Text(item.typeName)
                    .fontSize(13)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#ffffff')
                  Text(item.level)
                    .fontSize(11)
                    .fontColor('rgba(255,255,255,0.7)')
                    .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                    .backgroundColor('rgba(255,255,255,0.15)')
                    .borderRadius(4)
                }

                Text(item.text)
                  .fontSize(12)
                  .fontColor('rgba(255,255,255,0.8)')
                  .maxLines(5)
                  .lineHeight(18)
                  .margin({ top: 4 })

                Row({ space: 8 }) {
                  Text(`发布: ${item.pubTime}`)
                    .fontSize(10)
                    .fontColor('rgba(255,255,255,0.45)')
                  Text(`至 ${item.endTime}`)
                    .fontSize(10)
                    .fontColor('rgba(255,255,255,0.45)')
                  Blank()
                  Text(item.sender)
                    .fontSize(10)
                    .fontColor('rgba(255,255,255,0.4)')
                }
                .width('100%')
                .margin({ top: 2 })
              }
              .width('100%')
              .padding({ left: 14, right: 14, top: 10, bottom: 10 })
            }
            .width('100%')
          })
        }
        .width('100%')
        .backgroundColor('rgba(0,0,0,0.35)')
        .borderRadius({ bottomLeft: 10, bottomRight: 10 })
      }
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 6, bottom: 4 })
    .hitTestBehavior(HitTestMode.Block)
  }
}
