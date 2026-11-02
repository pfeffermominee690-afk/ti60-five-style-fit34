# 五风格开机自启动

本目录提供 fit32 的完整 FPGA 工程、RISC-V 固件、模型启动包，以及 Flash 打包、备份、烧录和恢复工具。

上电后，FPGA 配置携带的 RAM 初值启动 RISC-V。固件通过 `apb_boot_spi` 读取模型头，将参数加载到 DDR `0x02f00000`，检查模型 CRC32 和 DDR 回读，再启动五风格视频处理与手势切换。固件源码位于 `firmware/network_autoboot.c`，启动加载器共用根目录 `firmware/include/boot_flash.h`。

## Flash 布局

适用设备为工程使用的 8 MiB SPI Flash。配置区从 `0x000000` 开始，必须小于 4 MiB；模型头从 `0x400000` 开始，占 256 字节；其后为 330136 字节模型，CRC32 为 `c337ba5c`。`prebuilt/` 保存对应配置和模型包。

## 配置开发板

保持开发板供电和 USB 调试连接，关闭其他占用 JTAG 的调试器。在项目根目录执行：

```powershell
# 只生成配置与模型烧录文件，不访问硬件
python autoboot/flash.py prepare

# 读取完整 Flash 备份
python autoboot/flash.py backup

# 先备份，再分别写入自启动配置和模型，并逐字节回读校验
python autoboot/flash.py program

# 恢复指定备份目录中的完整 Flash 内容
python autoboot/flash.py restore --backup-dir 'build/autoboot-flash/session-实际备份目录'
```

`program` 会把配置区切换为本目录的 fit32 自启动工程。完成后断开 USB 调试连接，重新给开发板供电即可启动。备份和操作输出位于 `build/autoboot-flash/`，恢复工具会先检查备份大小和 SHA-256。工具路径通过 `--efinity-home` 指定。

## 编译

```powershell
python tools/build_firmware.py --target autoboot --update-ram
./build-fpga.ps1 -Target autoboot
```

以上命令输出固件至 `build/autoboot/`、新位流至 `autoboot/fpga/outflow/`。烧录工具使用 `prebuilt/` 中与模型头匹配的参考文件；修改启动固件、模型或 Flash 布局后，应同步维护这些配套文件和校验清单。
