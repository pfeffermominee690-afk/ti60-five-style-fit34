# 五风格模型

`models-five-fit24-compat.bin` 是五风格工程使用的部署包。屏幕名称、固件编号和模型目录一一对应：

| 固件编号 | 屏幕名称 | 模型目录 |
|---|---|---|
| 0 | 木刻 | `Lu-Xun-woodcut` |
| 1 | 点彩 | `Portrait-de-Metzinger(part)` |
| 2 | 排线速写 | `Leonardo-da-Vinci-Helicopter` |
| 3 | 鲜明色彩 | `Matisse-Woman-with-a-Hat` |
| 4 | 蓝黄笔触 | `Van-Gogh-The-Starry-Night` |

名称映射也保存在根目录 `styles.json`，OSD 字模由 `tools/generate_fonts.py` 生成。`models.bin` 是导出程序用于一致性校验的双风格基础包，运行五风格时使用上述五风格部署包。

原始模型、量化权重和整数参考位于 `model-source/`。安装该目录的依赖后，在项目根目录运行 `python tools/export_models.py`；导出结果位于 `build/`，并与部署包进行一致性校验。
