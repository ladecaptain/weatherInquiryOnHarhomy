/**
 * 搜索栏组件
 * 包含城市名输入框和查询按钮，支持回车搜索
 */
@Component
export struct SearchBar {
  @Link cityName: string
  onSearch: () => void = () => {}

  build() {
    Row() {
      TextInput({ text: this.cityName, placeholder: '请输入城市名...' })
        .layoutWeight(1)
        .height(44)
        .fontSize(16)
        .backgroundColor('#ffffff')
        .borderRadius(10)
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => {
          this.cityName = value
        })
        .onSubmit(() => {
          this.onSearch()
        })

      Button('查询')
        .fontSize(16)
        .height(44)
        .padding({ left: 16, right: 16 })
        .borderRadius(10)
        .backgroundColor('#007bff')
        .fontColor('#ffffff')
        .onClick(() => {
          this.onSearch()
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor('rgba(255, 255, 255, 0.85)')
    .backdropBlur(10)
  }
}
