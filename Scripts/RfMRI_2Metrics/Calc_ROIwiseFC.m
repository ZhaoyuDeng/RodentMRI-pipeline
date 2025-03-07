% Calculate ROI-wise Functional Connectivity 
% Adapted from Siying Tech's scripts
% Zhaoyu Deng, zhaoyu_deng@163.com
% 2025/03/06

clear; clc;

% Parameters
% Input directory above all sub* data
dataRoot = '/data1/projects/zhaoyu/Pers_XvJingsi/XJS_CON_8_Process';
% Folder include ROIs
seedRoot = '/data1/projects/zhaoyu/Pers_XvJingsi/ROI';


% get all folders with 'sub' prefix
subjNames = dir([dataRoot ,  filesep, 'sub*']);


for  i=1:length(subjNames)
    subjName = subjNames(i).name;
    % preprocessed data, without smooth
    nii_file = [data_root, filesep, subjName, filesep, 'FunImgARWDCF', filesep, 'fcdwrasrest.nii'];
    % get all ROIs
    seedlist= dir([seedRoot, filesep, '*.nii']);
    ts = [];
    % get all mean value in ROIs
    for j = 1:length(seedlist)
        seedfile = seedlist(j).name;
        seedmask = [seedRoot, filesep, seedfile];
        ts0=JQ_extractROIts(nii_file, seedmask, 'mean');
        ts=[ts,ts0];
    end
    % correlation (FC)
    corrmat=corr(ts);
    % Fisher z-transformation
    zcorrmat=atanh(corrmat);
    % set diagonal to 0
    zcorrmat(diag(diag(zcorrmat))~=0)=0;

    % save result
    save_dir = [data_root, filesep, subjName, filesep, 'ROIwiseFC'];
    if ~exist(save_dir,'dir')
        mkdir(save_dir)
    end
    save([save_dir, filesep, 'FC_',subjName, '.txt'], 'corrmat', '-ascii');
    save([save_dir, filesep, 'zFC_',subjName, '.txt'], 'zcorrmat', '-ascii');
    
    disp([subjName,'  done...']);
end