# 独立 Sobel 线条 Demo

本工程通过 CSI 采集、Bayer 转 RGB、缩放、Sobel 线条提取、DDR 帧缓存和 HDMI 输出形成完整视频通路，不需要神经网络模型。处理分辨率为 640×480；画面顶部显示 `LINE ART 640X480 FPS`。FPS 表示实际完成帧率。

在项目根目录运行 `./load.ps1 -Target line`。固件入口为 `firmware/capture_demo.c`，主要图像模块为 `fpga/rtl/capture_sobel.sv`，摄像头驱动和寄存器表位于 `firmware/`。

可调参数：`demo_mode=1` 显示线条、`0` 显示原图；`line_threshold=12` 控制轮廓门槛；`diagnostic_view=1` 打开详细统计。通过调试器修改变量可即时观察，修改源码后可重新编译。

```powershell
python tools/build_firmware.py --target line --update-ram
./build-fpga.ps1 -Target line
```

上述命令从项目根目录执行。固件生成在 `build/line/`，位流生成在 `line-demo/fpga/outflow/`。Sobel 的图像质量、RGB 旁路、DDR 校验、显示和摄像头驱动测试见 `tests/`。
