#!/bin/bash
# Apply mask to T2 and rest
# Zhaoyu Deng, zhaoyu_deng@163.com
# 2025/03/04

# Parameters
dataRoot="/data1/projects/zhaoyu/Pers_XvJingsi/XJS_CON_8_Process"

allSub=$(ls -A $dataRoot)

for sub in ${allSub[@]}; do
    echo $dataRoot/$sub
    fslmaths $dataRoot/$sub/T2/sT2.nii -mul $dataRoot/$sub/T2/sT2_mask.nii $dataRoot/$sub/T2/sT2_inmask.nii.gz
    fslmaths $dataRoot/$sub/rest/meanasrest.nii -mul $dataRoot/$sub/rest/meanasrest_mask.nii $dataRoot/$sub/rest/meanasrest_inmask.nii.gz
    fslmaths $dataRoot/$sub/rest/rasrest.nii -mul $dataRoot/$sub/rest/meanasrest_mask.nii $dataRoot/$sub/rest/rasrest_inmask.nii.gz
done
