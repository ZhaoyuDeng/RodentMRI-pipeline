# 小鼠rfMRI数据处理流程

## 数据准备
- ​**T2、BOLD**​（包括Template、Atlas使用前都需要放大）
  - 使用 `step0_multiVs.m` 放大10倍

## 参数获取
- 查看原始文件参数，获得 `sliceorder` 等关键参数
  - 使用 `step1.m`，输入 `nslice`、`TR`、`slice order`、`reference slice`、`nscan`，运行

## 数据方向与原点调整
- 使用 `spm fmri display` 调整T2数据方向和原点
  - `set origin`，`Reorient` 保存到同一文件
  - 重新调整 `meanarest.nii` 数据方向和原点
    - `set origin`，`Reorient` 中选择目标为 `^ra.*/Inf` 和 `meanarest` 的文件应用
    - （原点选择在TMB模板为第3脑室）

## 创建Mask
- 使用 `ITK-Snap` 创建T2和 `meanarest` 的mask

## 剥头皮
- 使用 `step2_ApplyMask.sh` 剥头皮（应用mask）

## 降采样
- 使用 `restplus` 的 `Reslice`，对放大10倍后 `TMB_Template`（voxelsize 0.6）进行voxelsize `[1.2 1.2 1.2]` 的 `downsample 2`（2倍降采样），共5个文件

## 配准
- 使用 `step3_ANTs.sh`，使用ANTs的命令进行 `register`，输入前述 `downsample` 的 `Template`

## 平滑
- 使用 `step4_Smooth`，使用 `FWHM[4 4 4]` 对 `wrarest` 平滑，得到 `swrarest`

## 降噪与滤波
- 使用 `step5_DenoiseFilter.m`，计算头动、降噪、滤波、去线性等；一次性输出3种结果

| 指标         | 对应文件夹 | 备注         | 对应文件     |
|--------------|------------|--------------|--------------|
| ALFF         | ARWSDC     | 无Filter     | cdswrarest   |
| ReHo         | ARWDCF     | 无Smooth     | fcdwrarest   |
| voxelwiseFC  | ARWSDCF    | 都做         | fcdswrarest  |
| ROIwiseFC    | ARWDCF     | 无Smooth     | fcdwrarest   |