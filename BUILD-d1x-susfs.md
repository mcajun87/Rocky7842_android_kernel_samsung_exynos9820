# d1x 内核构建说明（KernelSU-Next + SUSFS v2.0.0）

本分支在 **Rocky7842 的 `lineage-24.0-ksu`** 基础上集成了 **SUSFS v2.0.0**，用于
Samsung Galaxy Note10 5G（d1x / SM-N971N，Exynos 9825，内核 4.14.357-openela）。

## 一、SUSFS 来源

内核侧代码取自 `ProjectMatrixx-exynos9820/android_kernel_samsung_exynos9820` 分支
`ksunext-susfs` 的提交 `b231077 [BACKPORT] fs: implement susfs v2.0.0`
（24 个文件 / 2629 行），以 patch 方式套用后再针对本树适配。

用户态模块用 `sidex15/susfs4ksu-module`（v1.5.2+_R28，支持 susfs v2.0.0+/v2.1.0+）。

## 二、本树做的适配（相对原 patch）

1. `fs/exec.c`、`fs/namespace.c`：原 patch 的声明块被插进了 `/* */` 注释内部，
   需移到注释之外（否则整块失效或出现 `#endif without #if`）。
2. `fs/namespace.c`：参考树的 `mnt_free_group_id` 在本树叫 `mnt_release_group_id`；
   `mnt_alloc_group_id` 用旧版 ida API，需改写为 `ida_pre_get/ida_get_new_above`。
3. `fs/proc/task_mmu.c`：
   - extern 声明不能夹在函数签名与 `{` 之间；
   - 4.19+ 的 `show_smaps_rollup` 逻辑在 4.14 不存在，误落进 `show_smap` 必须删除；
   - **4.14 没有 `seq_put_hex_ll()`**，SUS_MAP 伪装改用内核原生
     `show_vma_header_prefix(m, start, end, 0, 0, 0, 0)`（flags 传 0 正好输出 `---p`）。
4. KernelSU-Next 胶水（本树为扁平目录结构）：
   - `drivers/kernelsu/supercall/supercall.c`：`SUSFS_MAGIC` 命令分发（15 条）
   - `drivers/kernelsu/selinux/selinux.c`：`susfs_is_current_ksu_domain()`、
     `susfs_ksu_sid` / `susfs_priv_app_sid` 定义与初始化
   - `drivers/kernelsu/core/init.c`：调用 `susfs_init()`
   - `drivers/kernelsu/runtime/boot_event.c`：`on_boot_completed()` 里置位
     `susfs_is_boot_completed_triggered`
   - `drivers/kernelsu/feature/kernel_umount.c`：`try_umount()` 去掉 `static`
   - `drivers/kernelsu/feature/sucompat.c`：`ksu_handle_devpts()`（当前为空实现）
   - `drivers/kernelsu/Kconfig`：新增 SUSFS 菜单（11 个 config）
5. `arch/arm64/configs/exynos9820-d1x_defconfig`：启用 11 个 `CONFIG_KSU_SUSFS*`。

## 三、编译

```bash
bash build-d1x-susfs.sh          # 增量
bash build-d1x-susfs.sh clean    # 全量
```

产物：`out-d1x/arch/arm64/boot/Image`（约 49.3 MB）。

## 四、打刷机包（AnyKernel3）

```bash
git clone https://github.com/osm0sis/AnyKernel3
cp out-d1x/arch/arm64/boot/Image AnyKernel3/
cd AnyKernel3
```

`anykernel.sh` 必须改这三处（**踩过的坑**）：

1. `BLOCK=/dev/block/platform/13d60000.ufs/by-name/boot;`
   —— 模板默认是 TI OMAP 的路径，不改会报
   `Unable to determine /dev/block/platform/omap/... partition. Aborting...`
2. 把模板里 **Galaxy Nexus (tuna) 专用**的命令全部注释：
   `backup_file init.tuna.rc`、`insert_line init.tuna.rc ... omap ...`、
   `patch_fstab fstab.tuna ...`，只保留 `dump_boot;` 与 `write_boot;`
3. `device.name1=d1x`，`do.devicecheck=1`，`do.backup=1`（备份原始 boot 到 /sdcard）

打包：`zip -r d1x-kernel.zip . -x ".git/*"`

## 五、验证（实机）

```bash
adb shell cat /proc/version        # 应含本分支提交号
adb shell "logcat -b kernel -d | grep susfs"
# 期望看到:
#   susfs: [0][pid][susfs_show_version] CMD_SUSFS_SHOW_VERSION -> ret: 0
adb shell su -c 'ksu_susfs show version'   # 需在管理器授权 shell
```
