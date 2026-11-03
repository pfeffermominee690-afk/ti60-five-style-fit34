# 测试

从项目根目录运行。Python 校验只需要标准库；硬件逻辑测试需要 Linux/WSL 中的 GCC、Icarus Verilog 和 Verilator。

| 命令 | 覆盖范围 |
|---|---|
| `python tools/verify.py` | 整包哈希、三个 FPGA 工程依赖、固件 RAM 初值、位流、模型和风格映射 |
| `python tools/build_firmware.py --target main --check-reference` | 五风格固件重建与参考二进制比较 |
| `python tools/build_firmware.py --target line --check-reference` | 线条固件重建与参考二进制比较 |
| `python tools/build_firmware.py --target autoboot --check-reference` | 自启动固件重建与参考二进制比较 |
| `bash tests/run.sh` | 自动曝光、Bayer 插值、归一化、手势和风格字幕 |
| `bash tests/rotation/run.sh` | fit37 整屏旋转、AXI 反压与 4 KiB 边界、帧中断及错误恢复、五种字幕与同步时序 |
| `bash line-demo/tests/run.sh` | 摄像头 I²C、Sobel 图像质量、RGB 旁路、DDR、OSD 与完整视频通路 |
| `python autoboot/tests/test_flash.py` | 启动包格式、CRC、分区边界、备份／写入顺序和无效备份拒绝；使用模拟设备 |
| `bash autoboot/tests/run.sh` | 启动 SPI 的字节传输与 APB 访问 |
| `bash autoboot/tests/run.sh --full` | 增加真实 RISC-V 固件的模型加载、CRC 回读和损坏模型拒绝仿真 |

`--full` 需要仿真完整模型的串行加载，运行时间较长。测试输出统一写入 `build/`。`tools/generate_fonts.py` 依赖 Pillow 与指定字体，可检查生成字模和参考 ROM 是否一致。
