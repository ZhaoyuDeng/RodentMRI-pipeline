% Detrend & nuisance coviriates regression & filter
% Adapted from Siying Tech's scripts
% Zhaoyu Deng, zhaoyu_deng@163.com
% 2025/03/06

clear;clc;

% Parameters
% Input directory above all sub* data
dataRoot = '/data1/projects/zhaoyu/Pers_XvJingsi/XJS_CON_8_Process';
TemplateDir = '/data1/projects/zhaoyu/Github/RodentMRI-pipeline/Templates/TMBTA_Scale10Downsample2';
% headmotion regression mod
covmod = 4;
% TR for filtering
TR = 2;
% The frequency for filtering
band = [0.01 0.08];


%Template brain mask
brainMask = [TemplateDir,filesep,'TMBTA_Brain_Mask.nii'];
%WM mask
WMMask = [TemplateDir,filesep,'TMBTA_White.nii'];
%CSF mask
CSFMask = [TemplateDir,filesep,'TMBTA_CSF.nii'];
% get all folders with 'sub' prefix
subjNames = dir([dataRoot, filesep, 'sub*']);

% Calculate ARWSDC£¬no Filter£¬for ALFF and fALFF
for i=1:length(subjNames)
    subjName = subjNames(i).name;
    % preprocessed data with smooth
    nii_file = [dataRoot, filesep, subjName, filesep,'rest',filesep,'swrasrest_inmask.nii'];
    save_dir = [dataRoot, filesep, subjName, filesep,'FunImgARWSDC']; 
    % head motion
    rp_file = [dataRoot, filesep, subjName, filesep,'rest',filesep,'rp_asrest.txt'];   
    % addmean: whether add mean back,1 or 0
    addmean=1;
    % Dertend
    Detrend=1;
    % denosing
    RatfMRI_denoising(nii_file, brainMask, TR, [], rp_file, save_dir,covmod,addmean,Detrend,WMMask,CSFMask);  
    movefile([save_dir,filesep,'denoised_rest.nii'],[save_dir,filesep,'cdswrasrest.nii']);
    disp([subjName, '  done...']);
end

% Calculate ARWDCF£¬no Smooth£¬for ReHo and ROI-wise FC
for i=1:length(subjNames)
    subjName = subjNames(i).name;
    % preprocessed data without smooth
    nii_file = [dataRoot, filesep, subjName, filesep,'rest',filesep,'wrasrest_inmask.nii'];
    save_dir = [dataRoot, filesep, subjName, filesep,'FunImgARWDCF']; 
    % head motion
    rp_file = [dataRoot, filesep, subjName, filesep,'rest',filesep,'rp_asrest.txt'];
    %addmean: whether add mean back,1 or 0
    addmean=1;
    % Dertend
    Detrend=1;
    % denosing
    RatfMRI_denoising(nii_file, brainMask, TR, band, rp_file, save_dir,covmod,addmean,Detrend,WMMask,CSFMask);  
    movefile([save_dir,filesep,'denoised_rest.nii'],[save_dir,filesep,'fcdwrasrest.nii']);
    disp([subjName, '  done...']);
end

% Calculate ARWSDCF£¬with Smooth & Filter£¬for voxel-wise FC
for i=1:length(subjNames)
    subjName = subjNames(i).name;
    % preprocessed data with Smooth & Filter
    nii_file = [dataRoot, filesep, subjName, filesep,'rest',filesep,'swrasrest_inmask.nii'];
    save_dir = [dataRoot, filesep, subjName, filesep,'FunImgARWSDCF'];  
    % head motion
    rp_file = [dataRoot, filesep, subjName, filesep,'rest',filesep,'rp_asrest.txt'];
    % addmean: whether add mean back,1 or 0
    addmean=1;
    % Dertend
    Detrend=1;
    % denosing
    RatfMRI_denoising(nii_file, brainMask, TR, band, rp_file, save_dir,covmod,addmean,Detrend,WMMask,CSFMask);  
    movefile([save_dir,filesep,'denoised_rest.nii'],[save_dir,filesep,'fcdswrasrest.nii']);
    disp([subjName, '  done...']);
end

