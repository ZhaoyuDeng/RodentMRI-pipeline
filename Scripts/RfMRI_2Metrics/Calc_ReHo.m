% Calculate Regional Homogeneity (ReHo) 
% Adapted from Siying Tech's scripts
% Zhaoyu Deng, zhaoyu_deng@163.com
% 2025/03/06

clear; clc;

% Parameters
% Input directory above all sub* data
dataRoot = '/data1/projects/zhaoyu/Pers_XvJingsi/XJS_CON_8_Process';
TemplateDir = '/data1/projects/zhaoyu/Github/RodentMRI-pipeline/Templates/TMBTA_Scale10Downsample2';
% TR for filtering
TR = 2;
% The frequency for filtering
band = [0.01 0.08];
% Smooth kernel
% The FWHM of the Gaussian kernel is often recommended to be 1.5 to 2 times, or even three times the voxel size
sm_kernel = [3 3 3]; 
% Template brain mask
brainMask = [TemplateDir,filesep,'TMBTA_Brain_Mask.nii'];



% get all folders with 'sub' prefix
subjNames = dir([dataRoot ,  filesep, 'sub*']);

for  i=1:length(subjNames)
    subjName = subjNames(i).name;
    
    % preprocessed data without smooth
    nii_file = [dataRoot, filesep, subjName, filesep, 'FunImgARWDCF', filesep, 'fcdwrasrest.nii'];
    % head motion
    rp_file = [dataRoot, filesep, subjName, filesep, 'rest', filesep, 'rp_asrest.txt'];

    save_dir = [dataRoot, filesep, subjName, filesep, 'ReHo'];
    if ~exist(save_dir,'dir')
        mkdir(save_dir)
    end

    % Calculate ReHo
    RatfMRI_reho(nii_file,brainMask,save_dir,sm_kernel);

    disp([subjName,'  done...']);
end