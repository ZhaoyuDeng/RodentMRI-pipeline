% Calculate ALFF and fALFF
% Adapted from Siying Tech's scripts
% Zhaoyu Deng, zhaoyu_deng@163.com
% 2025/03/06

clear; clc;

% Parameters
% Input directory above all sub* data
dataRoot = '/data1/projects/zhaoyu/Pers_XvJingsi/XJS_CON_8_Process';
% Directory of 
TemplateDir = '/data1/projects/zhaoyu/Github/RodentMRI-pipeline/Templates/TMBTA_Scale10Downsample2';
% TR for filtering
TR = 2;
% The frequency for filtering
band = [0.01 0.08];
% Template brain mask
brainMask = [TemplateDir,filesep,'TMBTA_Brain_Mask.nii'];


% get all folders with 'sub' prefix
subjNames = dir([dataRoot ,  filesep, 'sub*']);

for  i=1:length(subjNames)
    subjName = subjNames(i).name;

    % preprocessed data, no Filter
    nii_file = [dataRoot, filesep, subjName, filesep, 'FunImgARWSDC', filesep, 'cdswrasrest.nii'];
    nii_file = cellstr(nii_file);

    save_dir = [dataRoot, filesep, subjName, filesep, 'ALFF'];
    if ~exist(save_dir,'dir')
        mkdir(save_dir)
    end

    % Calculate ALFF & fALFF
    RatfMRI_alff_falff_ZZD(nii_file,brainMask,TR,band,save_dir);

    disp([subjName,'  done...']);
end

