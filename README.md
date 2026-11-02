# 流光绘影：Ti60 实时视频风格化系统

基于 Ti60F225 FPGA 和 SC431HAI CSI 摄像头，完成视频采集、五风格神经网络推理、原图与风格图 HDMI 显示，支持手势切换风格。本版本保留小蓝点与风格竖条修复、室外自动曝光和既有色彩参数。

## 工程结构

| 目录 | 内容 |
|---|---|
| `fpga/` | Efinity 工程、RTL、计算引擎、接口 IP、管脚与时序约束 |
| `firmware/` | RISC-V 固件、摄像头驱动、曝光控制、手势处理与 BSP |
| `models/` | 五风格部署模型及固定测试输入 |
| `model-source/` | 原模型源码、检查点、INT8 权重及量化参数 |
| `prebuilt/` | 配套 FPGA 位流和 RISC-V 固件 |
| `tools/` | 校验、固件编译、模型导出与调试工具 |
| `tests/` | 曝光、Bayer、归一化测试及参考数据 |
| `profiles/` | 室外曝光参数 |

## 使用

开发环境：Windows、Efinity 2025.1、RISC-V IDE 2025.1、Python 3。开发板需已预置 `models/models-five-fit24-compat.bin` 对应的五风格模型。连接 CSI 摄像头、USB 调试线和 HDMI 显示屏，在项目根目录执行：

```powershell
python tools/verify.py          # 检查文件完整性
./load.ps1                     # 加载程序并应用室外曝光参数
python tools/build_firmware.py  # 编译 RISC-V 固件
./build-fpga.ps1                # 编译 FPGA 工程
```

工具安装目录可通过 `load.ps1` 的 `-EfinityHome`、`-RiscvSdk` 和编译脚本的对应参数指定。模型导出运行 `python tools/export_models.py`，依赖见 `model-source/requirements.txt`。测试在装有 GCC 和 Icarus Verilog 的 Linux/WSL 中运行 `bash tests/run.sh`。

五种风格依次为木刻、梅青格肖像、达芬奇线稿、马蒂斯和星空。保留既有 FPS ×3 显示规则；该屏显数值不代表实际推理吞吐，原板端测量约 9.03 fps。

厂商 IP 和原模型代码保留各自版权与许可。完整性校验使用 `manifest.json`；构建源码与位流对应关系见 `source-manifest.json`。
