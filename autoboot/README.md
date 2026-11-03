# 五风格开机自启动

烧录工具支持当前主工程 fit37 和历史工程 fit32。本目录保留 fit32 的完整 FPGA 工程、RISC-V 固件及共用模型启动包；fit37 源码位于根目录 `fpga/`、`firmware/`，对应文件为 `prebuilt/fit37.bit` 和 `prebuilt/fit37.hex`。

上电后，FPGA 配置携带的 RAM 初值启动 RISC-V。固件通过 `apb_boot_spi` 读取模型头，将参数加载到 DDR `0x02f00000`，检查模型 CRC32 和 DDR 回读，再启动五风格视频处理与手势切换。fit37 使用根目录的 `firmware/src/network_camera.c`，fit32 使用本目录的 `firmware/network_autoboot.c`，二者共用根目录 `firmware/include/boot_flash.h`。

## Flash 布局

适用设备为工程使用的 8 MiB SPI Flash。配置区从 `0x000000` 开始，必须小于 4 MiB；模型头从 `0x400000` 开始，占 256 字节；其后为 330136 字节模型，CRC32 为 `c337ba5c`。`prebuilt/` 保存对应配置和模型包。

## 配置开发板

保持开发板供电和 USB 调试连接，关闭其他占用 JTAG 的调试器。在项目根目录执行：

```powershell
# 只生成配置与模型烧录文件，不访问硬件
python autoboot/flash.py prepare --target main

# 读取完整 Flash 备份
python autoboot/flash.py backup --target main

# 先备份，再分别写入自启动配置和模型，并逐字节回读校验
python autoboot/flash.py program --target main

# 恢复指定备份目录中的完整 Flash 内容
python autoboot/flash.py restore --backup-dir 'build/autoboot-flash/session-实际备份目录'
```

`--target main` 选择 fit37，`--target autoboot` 选择历史 fit32；省略参数时保留原工具的 fit32 默认行为。烧录前备份完整 Flash，随后写入模型与所选配置并逐字节回读。完成后重新给开发板供电，检查是否从 Flash 独立启动。备份和操作输出位于 `build/autoboot-flash/`，恢复工具会先检查备份大小和 SHA-256。工具路径通过 `--efinity-home` 指定。当前板卡验证状态见 [fit37 验证资料](../docs/validation/fit37/README.md)。

fit37 固件自带自动曝光。`load.ps1 -Profile outdoor` 额外应用的室外曝光目标属于运行时配置，重新上电后使用固件中的默认目标。

## 编译

本目录的历史 fit32 工程：

```powershell
python tools/build_firmware.py --target autoboot --update-ram
./build-fpga.ps1 -Target autoboot
```

以上命令输出固件至 `build/autoboot/`、新位流至 `autoboot/fpga/outflow/`。烧录工具使用 `prebuilt/` 中与模型头匹配的参考文件；修改启动固件、模型或 Flash 布局后，应同步维护这些配套文件和校验清单。

编译当前 fit37 时使用 `python tools/build_firmware.py --target main --update-ram` 和 `./build-fpga.ps1 -Target main`，输出位于 `build/main/` 与 `fpga/outflow/`。
