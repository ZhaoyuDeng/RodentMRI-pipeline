% Calculate voxel-wise Functional Connectivity 
% Adapted from Siying Tech's scripts
% Zhaoyu Deng, zhaoyu_deng@163.com
% 2025/03/06

clear; clc;

% Parameters
% Input directory above all sub* data
dataRoot = '/data1/projects/zhaoyu/Pers_XvJingsi/XJS_CON_8_Process';
TemplateDir = '/data1/projects/zhaoyu/Github/RodentMRI-pipeline/Templates/TMBTA_Scale10Downsample2';
% Folder include ROIs
seedRoot = '/data1/projects/zhaoyu/Pers_XvJingsi/ROI';
% Template brain mask
brainMask = [TemplateDir,filesep,'TMBTA_Brain_Mask.nii'];



% get all folders with 'sub' prefix
subjNames = dir([dataRoot ,  filesep, 'sub*']);


for  i=1:length(subjNames)
    subjName = subjNames(i).name;

    nii_file = [dataRoot, filesep, subjName, filesep, 'FunImgARWSDCF', filesep, 'fcdswrasrest.nii'];
    % get all ROIs
    seedlist= dir([seedRoot, filesep, '*.nii']);
    for j = 1:length(seedlist)
        seedfile = seedlist(j).name;
        seedmask = [seedRoot, filesep, seedfile];
        % save result
        save_dir = [dataRoot, filesep, subjName, filesep, 'VoxelwiseFC', filesep, seedfile(1:end-4)];
        if ~exist(save_dir,'dir')
            mkdir(save_dir)
        end
        % Calculate voxel-wise FC
        RatfMRI_voxelFC(nii_file, brainMask, seedmask, save_dir)
    end

    disp([subjName,'  done...']);
end