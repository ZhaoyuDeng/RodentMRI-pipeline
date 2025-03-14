# Mouse Resting-State Functional Magnetic Resonance Imaging Manual - English Version

## Parameter Acquisition

Before data processing, key parameters of the rfMRI sequence need to be obtained:
> If using Bruker MRI, these can be found in the `acqp` file of the rfMRI sequence in the source data

| Parameter        | Variable Name | Comment |
| ------------------ | --------------- |--------------- |
| number of slices | nslices       | found in `acqp` parameter `NSLICES`|
| repetition time  | TR            | found in `acqp` parameter `ACQ_repetition_time` |
| slice order   | slice_order | MATLAB index starts with 1, found in `acqp` parameter `ACQ_obj_order`|
|  reference slice  | reference_slice  | if number of slices is even, choose either in the middle. |
| number of scans   | n_scan   | time points. found in `acqp` parameter `ACQ_obj_order`|


## Data Preparation

#### File Format Conversion

1. Use the `Toolboxs/dcm2niix` tool in the command line to convert `DICOM` files to `NIfTI` files.
> You can refer to this script: `Scripts/Utilities/Convert2NIfTI.sh`

2. Check the data and manually organize them according to the following data structure:

```
.
└── sub1
    ├── rest
    │   └── rest.nii
    └── T2
        └── T2.nii
```
## Data Preprocessing
Data preprocessing scripts are stored in `Scripts/RfMRI_1Preproc_Mouse/`.

### 1. 10x Scaling, Slice Timing Correction, and Realignment
```
Script: step1_X10SliTimRealign.m
Function: This script scales the image by 10 times, performs slice timing correction, and calculates head motion (Realign)
Input:
Files: T2.nii, rest.nii
Parameters:
    1. nslices: Number of image slices
    2. TR: Image acquisition time interval
    3. slice_order: Image acquisition order
    4. reference_slice: Reference slice
    5. n_scan: Number of image acquisition time points
Output:
Files: sT2.nii, rasrest.nii, meanasrest.nii, rp_asrest.txt
```
Open `step1_X10SliTimRealign.m` in MATLAB, modify dataRoot and other parameters, and run.
> PS. The script does not have the functionality to remove the first n time points, which will be added later.

### 2. Origin Correction and Mask Generation
<img src="assets\20250307_104522_image.png" alt="image" width="250" height="auto">

#### Origin Correction for T2 Image
Use the `Display` tool in `spm fmri` to correct the origin of `sT2.nii`.
> Specific operation:
> In MATLAB, input and run `spm fmri`, select the `Display` tool, adjust `sT2.nii` according to the orientation and origin position shown in the above figure; after adjustment, first click `Set Origin`, then click `Reorient`; select `sT2.nii`, and finally click `Done`. (This saves to the same file)

#### Origin Correction for rfMRI Images
Use the `Display` tool in `spm fmri` to correct the origin of `meanasrest.nii` and `rasrest.nii`.
> Specific operation:
> In MATLAB, input and run `spm fmri`, select the `Display` tool, adjust `meanasrest.nii` according to the orientation and origin position shown in the above figure; after adjustment, first click `Set Origin`, then click `Reorient`; first select `meanasrest.nii`, then fill in `^ra.*` in the Filter field and `Inf` in the Frames field, right-click and `Select All` to select all frames of `rasrest.nii`, and finally click `Done`.

#### Generating Masks
This step requires using tools to create masks for the origin-corrected `sT2.nii` and `meanasrest.nii`. The generated mask files need to be saved as `sT2_mask.nii` and `meanasrest_mask.nii` respectively.

**ITK-SNAP** is recommended for Generating masks. Though traditional manual tools like `FSLeyes` and `mrview` are also doable.

I have also tried deep learning methods such as [SHERM-rodentSkullStrip](https://github.com/liu-yikang/SHERM-rodentSkullStrip) and [MouseBrainExtractor](https://github.com/MouseSuite/MouseBrainExtractor), but the former cannot be completed stably, and the latter has not been successfully reproduced yet.

### 3. Skull Stripping
```
Script: step2_ApplyMask.sh
Function: Apply masks to sT2.nii, rasrest.nii, meanasrest.nii
Input:
Files: sT2.nii, rasrest.nii, meanasrest.nii, sT2_mask.nii, meanasrest_mask.nii
Parameters: None
Output:
Files: sT2_inmask.nii.gz, rasrest_inmask.nii.gz, meanasrest_inmask.nii.gz
```
Open `step2_ApplyMask.sh`, modify dataRoot, and run in Terminal.

### 4. Spatial Registration (Normalization)

```
Script: step3_ANTs.sh
Function: Use ANTs for spatial registration (Normalization)
Input:
Files: sT2_inmask.nii.gz, rasrest_inmask.nii.gz, meanasrest_inmask.nii.gz
Parameters: None
Output:
Files: wrasrest_inmask.nii
```
Open `step3_ANTs.sh`, modify dataRoot and Template, and run in Terminal.

### 5. Noise Smoothing
```
Script: step4_Smooth.m
Function: Smooth noise
Input:
Files: wrasrest_inmask.nii
Parameters:
    1. n_scan: Number of image acquisition time points
    2. smooth_fwhm: FWHM value for Gaussian smoothing
Output:
Files: swrasrest_inmask.nii
```
Open `step4_Smooth.m` in MATLAB, modify dataRoot and other parameters, and run.

### 6. Detrend, Motion Correction, Filtering, and Calculation of Various Measurements
```
Script: step5_DenoiseFilter.m
Function: Detrend, motion correction, filtering, and calculate various measurements
Input:
Files: wrasrest_inmask.nii, swrasrest_inmask.nii
Parameters:
    1. TR: Image acquisition time interval
    2. band: Filtering frequency range
Output:
Files: FunImgARWSDC/cdswrasrest.nii, FunImgARWDCF/fcdwrasrest.nii, FunImgARWSDCF/fcdswrasrest.nii
```
Open `step5_DenoiseFilter.m` in MATLAB, modify dataRoot, TemplateDir, and other parameters, and run.

## rfMRI Metrics Calculation
Scripts for rfMRI metrics calculation are stored in `Scripts/RfMRI_2Metrics/`.
| Metric        | Corresponding Folder | Note         | Corresponding File     |
|--------------|------------|--------------|--------------|
| ALFFfALFF    | ARWSDC     | No Filter     | cdswrasrest   |
| ReHo         | ARWDCF     | No Smooth     | fcdwrasrest   |
| voxelwiseFC  | ARWSDCF    | All do, ROI definition needed         | fcdswrasrest  |
| ROIwiseFC    | ARWDCF     | No Smooth, ROI definition needed     | fcdwrasrest   |
### 1. ALFF/fALFF (fractional / Amplitude of Low Frequency Fluctuations)
```
Script: Calc_ALFF_fALFF.m
Function: Calculate ALFF/fALFF, resulting in 3D images
Input:
Files: FunImgARWSDC/cdswrasrest.nii
Parameters:
    1. TR: Image acquisition time interval
    2. band: Filtering frequency range
Output:
Files: ALFF/ALFFMap.nii, m-1ALFFMap.nii, mALFFMap.nii, zALFFMap.nii, fALFFMap.nii, m-1fALFFMap.nii, mfALFFMap.nii, zfALFFMap.nii
```
Open `Calc_ALFF_fALFF.m` in MATLAB, modify dataRoot, TemplateDir, and other parameters, and run.

### 2. ReHo (Regional Homogeneity)
```
Script: Calc_ReHo.m
Function: Calculate ReHo, resulting in 3D images
Input:
Files: FunImgARWDCF/fcdwrasrest.nii, rp_asrest.txt
Parameters:
    1. TR: Image acquisition time interval
    2. band: Filtering frequency range
    3. sm_kernel: FWHM value for Gaussian smoothing
Output:
Files: ReHo/mReHoMap.nii, smReHoMap.nii, szReHoMap.nii, ReHoMap.nii, sReHoMap.nii, zReHoMap.nii
```
Open `Calc_ReHo.m` in MATLAB, modify dataRoot, TemplateDir, and other parameters, and run.

### 3. Voxel-wise Functional Connectivity
```
Script: Calc_VoxelwiseFC.m
Function: Calculate Voxel-wise Functional Connectivity, resulting in 3D images
Input:
Files: FunImgARWSDCF/fcdswrasrest.nii, all custom ROI files in the same folder
Parameters: None
Output:
Files: One whole-brain functional connectivity file per ROI
```
Open `Calc_VoxelwiseFC.m` in MATLAB, modify dataRoot, TemplateDir, and seedRoot, and run.

### 4. ROI-wise Functional Connectivity
```
Script: Calc_ROIwiseFC.m
Function: Calculate ROI-wise Functional Connectivity, resulting in an ROI count x ROI count matrix
Input:
Files: FunImgARWDCF/fcdwrasrest.nii, all custom ROI files in the same folder
Parameters: None
Output:
Files: One ROI count x ROI count functional connectivity matrix
```
Open `Calc_ROIwiseFC.m` in MATLAB, modify dataRoot, TemplateDir, and seedRoot, and run.

## rfMRI Metrics Statistics

## Results Visualization
