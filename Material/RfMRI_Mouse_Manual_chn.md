# 小鼠静息态功能磁共振成像手册 - 中文版

## 参数获取

在数据正式处理之前，需要获取rfMRI序列的关键参数：
> 如使用Bruker MRI，能在原始文件中rfMRI序列的`acqp`文件

| Parameter        | Variable Name | Comment |
| ------------------ | --------------- |--------------- |
| number of slices | nslices       | found in `acqp` parameter `NSLICES`|
| repetition time  | TR            | found in `acqp` parameter `ACQ_repetition_time` |
| slice order   | slice_order | MATLAB index starts with 1, found in `acqp` parameter `ACQ_obj_order`|
|  reference slice  | reference_slice  | if number of slices is even, choose either in the middle. |
| number of scans   | n_scan   | time points. found in `acqp` parameter `ACQ_obj_order`|


## 数据准备

#### 文件格式转换

1. 在命令行用`Toolboxs/dcm2niix`工具把`DICOM`文件转为`NIfTI`文件。
> 可参考此脚本：`Scripts/Utilities/Convert2NIfTI.sh`

2. 检查数据，并手动按照下面的数据结构整理数据：
（被试文件夹以“sub”开头即可）
```
.
└── sub01
    ├── rest
    │   └── rest.nii
    └── T2
        └── T2.nii
```
## 数据预处理
数据预处理的脚本存放在`Scripts/RfMRI_1Preproc_Mouse/`中。

### 1. 放大10倍、时间层校正(Slice Timing)、头动校正(Realign)
```
脚本：step1_X10SliTimRealign.m
功能：该脚本把图像放大10倍，并做时间层校正(Slice Timing)和计算头动(Realign)
输入：
文件：T2.nii、rest.nii
参数：
    1. nslices: 图像层数
    2. TR: 图像采集时间间隔
    3. slice_order: 图像采集顺序
    4. reference_slice: 参考层
    5. n_scan: 图像采集时间点数
输出：
文件：sT2.nii、rasrest.nii、meanasrest.nii、rp_asrest.txt
```
在 MATLAB 打开`step1_X10SliTimRealign.m`，修改dataRoot等参数并运行。
> PS. 脚本没有去除前n个时间点的功能，后续将会添加。

### 2. 原点校正、制作Mask
<img src="assets\20250307_104522_image.png" alt="image" width="250" height="auto">

#### 对T2图像进行原点校正
使用`spm fmri`的`Display`工具，对`sT2.nii`进行原点校正。
> 具体操作：
>在 MATLAB 输入并运行`spm fmri`，选择工具`Display`，按照上图的朝向和原点位置，调整`sT2.nii`；调整好后，先点`Set Origin`，再点击`Reorient`；选择`sT2.nii`，最后点击`Done`。（即保存到同一文件）

#### 对rfMRI图像进行原点校正
使用`spm fmri`的`Display`工具，对`meanasrest.nii`和`rasrest.nii`进行原点校正。
> 具体操作：
> 在 MATLAB 输入并运行`spm fmri`，选择工具`Display`，按照上图的朝向和原点位置，调整`meanasrest.nii`；调整好后，先点`Set Origin`，再点击`Reorient`；先选择`meanasrest.nii`，再在Filter一栏中填入`^ra.*`、Frames一栏中填入`Inf`，并右击鼠标`Select All`选择`rasrest.nii`的所有Frame，最后点击`Done`。

#### 制作Mask
本步骤需要使用工具对已经原点校正的`sT2.nii`和`meanasrest.nii`画Mask，生成的Mask文件需要分别保存为`sT2_mask.nii`和`meanasrest_mask.nii`。

推荐使用**ITK-SNAP**画Mask，`FSLeyes`、`mrview`等传统手动工具亦可。

本人也尝试过深度学习方法，如[SHERM-rodentSkullStrip](https://github.com/liu-yikang/SHERM-rodentSkullStrip)和[MouseBrainExtractor](https://github.com/MouseSuite/MouseBrainExtractor)，但前者不能稳定完成，后者尚未复现成功。

### 3. 剥头皮
```
脚本：step2_ApplyMask.sh
功能：把Mask应用到sT2.nii、rasrest.nii、meanasrest.nii
输入：
文件：sT2.nii、rasrest.nii、meanasrest.nii、sT2_mask.nii、meanasrest_mask.nii
参数：无
输出：
文件：sT2_inmask.nii.gz、rasrest_inmask.nii.gz、meanasrest_inmask.nii.gz
```
打开`step2_ApplyMask.sh`，修改dataRoot，并在Terminal中运行。

### 4. 空间配准(Registration/Normalization)

```
脚本：step3_ANTs.sh
功能：使用ANTs进行空间配准(Registration/Normalization)
输入：
文件：sT2_inmask.nii.gz、rasrest_inmask.nii.gz、meanasrest_inmask.nii.gz
参数：无
输出：
文件：wrasrest_inmask.nii
```
打开`step3_ANTs.sh`，修改dataRoot和Template，并在Terminal中运行。

### 5. 平滑噪声(Smooth)
```
脚本：step4_Smooth.m
功能：平滑噪声(Smooth)
输入：
文件：wrasrest_inmask.nii
参数：
    1. n_scan: 图像采集时间点数
    2. smooth_fwhm: 高斯平滑的FWHM值
输出：
文件：swrasrest_inmask.nii
```
在 MATLAB 打开`step4_Smooth.m`，修改dataRoot和其它参数并运行。

### 6. 去线性漂移、头动校正、滤波、计算多种测量值
```
脚本：step5_DenoiseFilter.m
功能：去线性漂移、头动校正、滤波、计算多种测量值 (Detrend & nuisance coviriates regression & filter)
输入：
文件：wrasrest_inmask.nii、swrasrest_inmask.nii
参数：
    1. TR: 图像采集时间间隔
    2. band: 滤波频率范围
输出：
文件：FunImgARWSDC/cdswrasrest.nii、FunImgARWDCF/fcdwrasrest.nii、FunImgARWSDCF/fcdswrasrest.nii
```
在 MATLAB 打开`step5_DenoiseFilter.m`，修改dataRoot、TemplateDir和其它参数并运行。

## rfMRI指标计算
rfMRI指标计算的脚本存放在`Scripts/RfMRI_2Metrics/`中。
| 指标         | 对应文件夹 | 备注         | 对应文件     |
|--------------|------------|--------------|--------------|
| ALFFfALFF    | ARWSDC     | 无Filter     | cdswrasrest   |
| ReHo         | ARWDCF     | 无Smooth     | fcdwrasrest   |
| voxelwiseFC  | ARWSDCF    | 都做、需要定义ROI         | fcdswrasrest  |
| ROIwiseFC    | ARWDCF     | 无Smooth、需要定义ROI     | fcdwrasrest   |
### 1. ALFF/fALFF (fractional / Amplitude of Low Frequency Fluctuations)
```
脚本：Calc_ALFF_fALFF.m
功能：计算ALFF/fALFF，得到3D图像
输入：
文件：FunImgARWSDC/cdswrasrest.nii
参数：
    1. TR: 图像采集时间间隔
    2. band: 滤波频率范围
输出：
文件：ALFF/ALFFMap.nii、m-1ALFFMap.nii、mALFFMap.nii、zALFFMap.nii、fALFFMap.nii、m-1fALFFMap.nii、mfALFFMap.nii、zfALFFMap.nii
```
在 MATLAB 打开`Calc_ALFF_fALFF.m`，修改dataRoot、TemplateDir和其它参数并运行。

### 2. ReHo (Regional Homogeneity)
```
脚本：Calc_ReHo.m
功能：计算ReHo，得到3D图像
输入：
文件：FunImgARWDCF/fcdwrasrest.nii、rp_asrest.txt
参数：
    1. TR: 图像采集时间间隔
    2. band: 滤波频率范围
    3. sm_kernel: 高斯平滑的FWHM值
输出：
文件：ReHo/mReHoMap.nii、smReHoMap.nii、szReHoMap.nii、ReHoMap.nii、sReHoMap.nii、zReHoMap.nii
```
在 MATLAB 打开`Calc_ReHo.m`，修改dataRoot、TemplateDir和其它参数并运行。

### 3. 基于体素的全脑功能连接 (Voxel-wise Functional Connectivity)
```
脚本：Calc_VoxelwiseFC.m
功能：计算Voxel-wise Functional Connectivity，得到3D图像
输入：
文件：FunImgARWSDCF/fcdswrasrest.nii、所有在同一文件夹下的自定义ROI文件
参数：无
输出：
文件：一个ROI一个全脑功能连接文件
```
在 MATLAB 打开`Calc_VoxelwiseFC.m`，修改dataRoot、TemplateDir和seedRoot并运行。

### 4. 基于ROI的功能连接 (ROI-wise Functional Connectivity)
```
脚本：Calc_ROIwiseFC.m
功能：计算ROI-wise Functional Connectivity，得到ROI数量xROI数量的矩阵
输入：
文件：FunImgARWDCF/fcdwrasrest.nii、所有在同一文件夹下的自定义ROI文件
参数：无
输出：
文件：一个ROI数量xROI数量的功能连接矩阵
```
在 MATLAB 打开`Calc_ROIwiseFC.m`，修改dataRoot、TemplateDir和seedRoot并运行。

## rfMRI指标统计

## 结果可视化