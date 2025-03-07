% Scale dmension unts x10 for animal scans, and Slice Timing & realign for rest
% Adapted from Siying Tech's scripts
% Zhaoyu Deng, zhaoyu_deng@163.com
% 2025/02/20

clear;clc;

% Parameters
% Input directory above all sub* data
dataRoot = '/data1/projects/zhaoyu/Pers_XvJingsi/XJS_CON_8_Process';

nslices = 25; % number of slices
TR = 2; % repetition time 
slice_order = [1:2:25,2:2:24]; % slice order, in MATLAB index starts with 1
reference_slice = 25; % reference slice 
n_scan = 300; % number of scans (time points)

%%
% get all folders with 'sub' prefix
subjNames = dir([dataRoot, filesep, 'sub*']);

% Scale dmension unts x10 for animal scans, T2 and rest
for i=1:length(subjNames)
    subjName = subjNames(i).name;

    restFile = [dataRoot, filesep, subjName, filesep, 'rest', filesep, 'rest.nii'];
    T2File = [dataRoot, filesep, subjName, filesep, 'T2', filesep, 'T2.nii'];
    % scale 10 times, with "s" prefix
    restFileX10 = [dataRoot, filesep, subjName, filesep, 'rest', filesep, 'srest.nii'];
    T2FileX10 = [dataRoot, filesep, subjName, filesep, 'T2', filesep, 'sT2.nii'];
    
    % Suplicate images
    copyfile(restFile,restFileX10);
    copyfile(T2File,T2FileX10);
    
    % Scale dmension unts 10 times for duplicated images
    JQ_multi_Vs(restFileX10, 10);
    JQ_multi_Vs(T2FileX10, 10);

    disp([subjName,'  done...']);
end

%% Slice Timing & realign for rest, using SPM
subjNames = dir([dataRoot, filesep, 'sub*']);

for i=1:length(subjNames)
    subjName = subjNames(i).name;
    % Generate every rest data list
    for j=1:n_scan 
        dataCell{j,1} = [dataRoot, filesep, subjName, filesep, 'rest',filesep, 'srest.nii,', num2str(j)];
    end
    % Slice Timing & realign using SPM
    matlabbatch{1}.spm.temporal.st.scans = {dataCell}';
    matlabbatch{1}.spm.temporal.st.nslices = nslices;
    matlabbatch{1}.spm.temporal.st.tr = TR;
    matlabbatch{1}.spm.temporal.st.ta = TR-TR/nslices;
    matlabbatch{1}.spm.temporal.st.so = slice_order;
    matlabbatch{1}.spm.temporal.st.refslice = reference_slice;
    matlabbatch{1}.spm.temporal.st.prefix = 'a';
    matlabbatch{2}.spm.spatial.realign.estwrite.data{1}(1) = cfg_dep('Slice Timing: Slice Timing Corr. Images (Sess 1)', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('()',{1}, '.','files'));
    matlabbatch{2}.spm.spatial.realign.estwrite.eoptions.quality = 0.9;
    matlabbatch{2}.spm.spatial.realign.estwrite.eoptions.sep = 4;
    matlabbatch{2}.spm.spatial.realign.estwrite.eoptions.fwhm = 5;
    matlabbatch{2}.spm.spatial.realign.estwrite.eoptions.rtm = 1;%regist to mean
    matlabbatch{2}.spm.spatial.realign.estwrite.eoptions.interp = 2;
    matlabbatch{2}.spm.spatial.realign.estwrite.eoptions.wrap = [0 0 0];
    matlabbatch{2}.spm.spatial.realign.estwrite.eoptions.weight = '';
    matlabbatch{2}.spm.spatial.realign.estwrite.roptionss.which = [2 1];
    matlabbatch{2}.spm.spatial.realign.estwrite.roptions.interp = 4;
    matlabbatch{2}.spm.spatial.realign.estwrite.roptions.wrap = [0 0 0];
    matlabbatch{2}.spm.spatial.realign.estwrite.roptions.mask = 1;
    matlabbatch{2}.spm.spatial.realign.estwrite.roptions.prefix = 'r';

    % Run batch
    spm_jobman('run', matlabbatch);

    disp([subjName,'  done...']);

    % Get maximum head motion for each subject after realign
    rp_file = [dataRoot, filesep, subjName, filesep,'rest',filesep,'rp_asrest.txt'];
    rp_max = JQ_estimate_maxRP(rp_file);

    rp_allsub{i,1} = subjName;
    rp_allsub{i,2} = rp_max;

end

% save([dataRoot, filesep, 'rp_allsub.mat'],'rp_allsub')