# fit37：摄像头五风格与整屏旋转

fit37 使用 J4 上的 SC431HAI 摄像头，保留 fit34 的 Bayer 彩点／竖条修正、自动曝光、五风格模型和原有色彩参数，将 HDMI 图像、FPS 与中文名称一起旋转 180°。HDMI 同步时序维持 1280×720，RISC-V 固件与模型保持不变。

## 使用

在仓库根目录运行 `./load.ps1 -Target main` 加载 fit37；运行 `./load.ps1 -Target fit34` 恢复未旋转显示。Flash 模型布局与两者共用的固件一致，烧录流程见 [自启动说明](../../../autoboot/README.md)。

| 文件 | SHA-256 |
|---|---|
| `prebuilt/fit37.bit` | `8c5f204dde7a94f03ec3d51f21302559d46756b2838fb36004b19d32edfd8883` |
| `prebuilt/network_camera.elf` | `6edd857b6b9fc079bc5e082ae37b043f4d030b9117fa9c89957dedbe75520753` |

## 验证

- 构建时序通过：最小 setup 余量 +0.188 ns，最小 hold 余量 +0.026 ns。DDR RX／TX 校准 setup 分别为 +0.258／+0.274 ns。
- 旋转仿真覆盖 3 个完整画面的 2,764,800 个像素，以及 AXI 反压、4 KiB 边界和帧中发布；错误恢复仿真校验 4,608,000 个像素；五种风格字幕、FPS 与同步信号共校验 4,608,000 个像素。
- 2026-11-03 真实 J4 摄像头运行：传感器初始化完成，处理帧计数由 167 增至 185，传感器 NACK、板级错误、HDMI 读取错误与欠载计数均为 0。用户确认“蓝点消失，方向正确”。见 [摄像头运行记录](camera-runtime.json) 与 [状态读取记录](camera-status.log)。
- fit37 配置已写入 Flash，整片 8 MiB 分段回读校验通过，模型与配置擦除区以外的数据保持不变。见 [Flash 校验记录](flash-persistence.json)、[配置写入与分段读取记录](flash/) 和 [擦除范围核对](flash/programming-audit.json)。
- 用户拔掉电脑 USB、等待 5 秒后接入充电宝，确认“自动出画面，方向正确、无蓝点，手势正常”。物理断电自启动及启动后的手势切换通过实机验收，见 [冷启动确认记录](cold-boot-user-confirmation.json)。

[原始构建审查](original-build-review.json) 和 [早期静态显示记录](original-static-validation.json) 按原样保留，其中摄像头验证字段反映早期测试条件；当前实时验证以 `camera-runtime.json` 为准。
