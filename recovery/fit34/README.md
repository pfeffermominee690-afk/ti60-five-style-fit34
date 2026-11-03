# fit34 恢复材料

fit34 保留未旋转的显示方向，包含 Bayer 彩点修正、自动曝光与原有色彩参数。`prebuilt/fit34.bit`、`prebuilt/fit34.hex` 和主工程共用的 `prebuilt/network_camera.elf` 均保留原始文件。

在仓库根目录临时加载 fit34：

```powershell
./load.ps1 -Target fit34
```

本目录的 `fpga/` 保存 fit34 与 fit37 不同的三个 RTL 文件及工程配置，其余 FPGA 源码、固件、模型与 fit37 共用。`source-manifest.json` 保留 fit34 的源码及位流哈希，根目录校验工具同时检查这套恢复材料。

需要独立编译 fit34 时，在仓库根目录复制到单独目录，再覆盖这四个文件：

```powershell
Copy-Item -LiteralPath fpga -Destination build/fit34-fpga -Recurse
Copy-Item recovery/fit34/fpga/* build/fit34-fpga/ -Recurse -Force
```

随后使用 Efinity 打开 `build/fit34-fpga/ti60f225_oob.xml` 编译。完整历史快照见 Git 标签 `fit34-recovery-20261103`，基线提交为 `73572cd3588f6880ab4492aa7ede6ba1e00b8cfa`。
