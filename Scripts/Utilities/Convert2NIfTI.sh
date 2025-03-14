#!/bin/bash
# Convert DICOM file to NIfTI
# Zhaoyu Deng, zhaoyu_deng@163.com
# 2025/02/19

INDIR="/data1/projects/zhaoyu/Pers_XvJingsi/XJS_CON_8_20250217"

# get all subjects' folder name
subNameList=($(ls -A $INDIR))

for subName in ${subNameList[@]}
do
    echo $subName
    /data1/projects/zhaoyu/Github/RodentMRI-pipeline/Toolboxs/dcm2niix -o "/data1/projects/zhaoyu/Pers_XvJingsi/XJS_CON_8_Dcm2nii" -f "sub"${subName:33} $INDIR/$subName

done

