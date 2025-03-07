#!/bin/bash
# Registration using ANTs
# Zhaoyu Deng, zhaoyu_deng@163.com
# 2025/03/04

Template="/data1/projects/zhaoyu/Github/RodentMRI-pipeline/Templates/TMBTA_Scale10Downsample2/TMBTA_Brain_Template.nii"
dataRoot="/data1/projects/zhaoyu/Pers_XvJingsi/XJS_CON_8_Process"
numThread=8

allSub=$(ls -A $dataRoot)

for sub in ${allSub[@]}; do
    echo $dataRoot/$sub
    antsRegistrationSyN.sh -d 3 -f $dataRoot/$sub/T2/sT2_inmask.nii.gz -m $dataRoot/$sub/rest/meanasrest_inmask.nii.gz -t 'r' -o $dataRoot/$sub/rest/f2a_
    antsRegistrationSyN.sh -d 3 -f $Template -m $dataRoot/$sub/T2/sT2_inmask.nii.gz -o $dataRoot/$sub/T2/a2t_ -n $numThread
    antsApplyTransforms -d 3 -e 3 -n Linear -i $dataRoot/$sub/rest/rasrest_inmask.nii.gz -o $dataRoot/$sub/rest/wrasrest_inmask.nii -r $Template -t $dataRoot/$sub/T2/a2t_1Warp.nii.gz -t $dataRoot/$sub/T2/a2t_0GenericAffine.mat -t $dataRoot/$sub/rest/f2a_0GenericAffine.mat 
done