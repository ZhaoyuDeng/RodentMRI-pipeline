% Smooth, after reoriented
% Zhaoyu Deng, zhaoyu_deng@163.com
% 2025/01/07

clear;clc;

% Parameters
% Input directory above all sub* data
dataRoot = '/data1/projects/zhaoyu/Pers_XvJingsi/XJS_CON_8_Process';
% number of scans (time points)
n_scan = 300; 
% S: smooth kernel, FWHM
smooth_fwhm = [4 4 4];


% get all folders with 'sub' prefix
subjNames = dir([dataRoot, filesep, 'sub*']);

for  i=1:length(subjNames)
    subjName = subjNames(i).name;

    for j=1:n_scan
        dataCell{j,1} = [dataRoot, filesep, subjName, filesep, 'rest', filesep, 'wrasrest_inmask.nii,', num2str(j)];
    end
    
    matlabbatch{1}.spm.spatial.smooth.data = dataCell;
    matlabbatch{1}.spm.spatial.smooth.fwhm = smooth_fwhm;
    matlabbatch{1}.spm.spatial.smooth.dtype = 0;
    matlabbatch{1}.spm.spatial.smooth.im = 0;
    matlabbatch{1}.spm.spatial.smooth.prefix = 's';
    
    % Run batch
    spm_jobman('run', matlabbatch);

    disp([subjName,'  done...']);
end

