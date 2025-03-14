function RatfMRI_denoising(AllVolume,AMaskFilename,TR,Band,rp_file,save_dir,covmod,addmean,Detrend,WMMaskFilename,CSFMaskFilename,FDThreshold)
% FORMAT RatfMRI_denoising(AllVolume,AMaskFilename,TR,Band,rp_file,save_dir,covmod,addmean,Detrend,WMMaskFilename,CSFMaskFilename,FDThreshold)
% AllVolume: 4D data nifti filename,string
% AMaskFilename: 3D mask nifti filename, string
% TR: TR for filtering, number
% Band:The frequency for filtering, 1*2 Array
% rp_file:rp*.txt filename for headmotion regression, string
% save_dir: output directory,string
% covmod: headmotion regression mod, number: 1 for 6 parameters, 2
% for 6now+6before and 3 for 6new+6square,4 for Friston 24
% addmean: whether add mean back,1 or 0
% Detrend:whether Detrend,1 or 0
% for 12 parameters, 4 for 24 parameters, default:4, optional
% WMMaskFilename: white matter mask for mean signals regression,string, optional
% CSFMaskFilename: CSF mask for mean signals regression,string, optional
% FDThreshold: FD threshold for headmotion timepoints scrubbing, optional
% revised by Qiu Jicheng,2021/10/03,qiu.jicheng@icloud.com
%% Read the functional images 
    % -------------------------------------------------------------------------
    fprintf('\n\t Read these 3D EPI functional images.\twait...');

    if ~isnumeric(AllVolume)
        [data, header_save] = y_Read(AllVolume);
        [AllVolume,vsize,theImgFileList, Header] = y_ReadAll(AllVolume);
    end
    [nDim1,nDim2,nDim3,nDimTimePoints]=size(AllVolume);
    mask = spm_read_vols(spm_vol(AMaskFilename));
    brind = find(mask~=0);
    AllVolume=reshape(AllVolume,[],nDimTimePoints)';
    AllVolume=AllVolume.*repmat(reshape(mask,[],1)',nDimTimePoints,1);
    %% Detrend
    if exist('Detrend','var') && Detrend==1;
        if ~exist('CUTNUMBER','var')
            CUTNUMBER = 10;
        end
        fprintf('\n\t Detrending...');
        SegmentLength = ceil(size(AllVolume,2) / CUTNUMBER);
        for iCut=1:CUTNUMBER
            if iCut~=CUTNUMBER
                Segment = (iCut-1)*SegmentLength+1 : iCut*SegmentLength;
            else
                Segment = (iCut-1)*SegmentLength+1 : size(AllVolume,2);
            end
            AllVolume(:,Segment) = detrend(AllVolume(:,Segment));
            fprintf('.');
        end
    end
    %% Covariate regression
    % WM & CSF signals
    if exist('WMMaskFilename','var') && exist('CSFMaskFilename','var')
        if ~isempty(WMMaskFilename) && ~isempty(CSFMaskFilename)
            WMmask = spm_read_vols(spm_vol(WMMaskFilename));
            WMCov= mean(AllVolume(:,find(WMmask)),2);
            CSFmask = spm_read_vols(spm_vol(CSFMaskFilename));
            CSFCov= mean(AllVolume(:,find(CSFmask)),2);
            covariate=[ones(size(AllVolume,1),1),WMCov,CSFCov];
        else
            covariate=ones(size(AllVolume,1),1);
        end
    else
        covariate=ones(size(AllVolume,1),1);
    end
    % head motion parameters
    if ~exist('covmod','var')
        covmod=4;
    end
    if ~exist('rp_file','var')
        rp_file='';
    end
    if ~isempty(rp_file)
        HMotion = load(rp_file);
        if covmod==1;
            covariate = [covariate,HMotion];
        elseif covmod==2;
            covariate = [covariate,HMotion,[zeros(1,size(HMotion,2));HMotion(1:end-1,:)]];
        elseif covmod==3;
            covariate = [covariate,HMotion,HMotion.^2];
        elseif covmod==4;
            covariate = [covariate,HMotion,[zeros(1,size(HMotion,2));HMotion(1:end-1,:)], HMotion.^2, [zeros(1,size(HMotion,2));HMotion(1:end-1,:)].^2];
        end
    end
        
    if exist('covariate','var') && ~isempty(covariate)
        if exist('addmean','var') && addmean==1
            fprintf('\n\t Covariate Regression...');
            beta=covariate\AllVolume(:,brind);
            AllVolume(:,brind) = AllVolume(:,brind) - covariate(:,2:end)*beta(2:end,:);
        else
            fprintf('\n\t Covariate Regression...');
            AllVolume(:,brind) = AllVolume(:,brind) - covariate*(covariate\AllVolume(:,brind));%
%             [b,r]=RegressCov(AllVolume(:,brind),covariate);
%             AllVolume(:,brind)=r;
        end
    end
    
    %% Filtering
    if exist('Band','var') && ~isempty(Band)
        if ~exist('CUTNUMBER','var')
            CUTNUMBER = 10;
        end
        if ~exist('TR','var')
            TR=2;
        end
        fprintf('\n\t Filtering...');
        SegmentLength = ceil(size(AllVolume,2) / CUTNUMBER);
        for iCut=1:CUTNUMBER
            if iCut~=CUTNUMBER
                Segment = (iCut-1)*SegmentLength+1 : iCut*SegmentLength;
            else
                Segment = (iCut-1)*SegmentLength+1 : size(AllVolume,2);
            end
            AllVolume(:,Segment) = y_IdealFilter(AllVolume(:,Segment), TR, Band);
            fprintf('.');
        end
    end
    
    %% Scrubbing (cut)
    % Calculate FD_Power
    if ~isempty(rp_file) && exist('FDThreshold','var') && ~isempty(FDThreshold)
        HMotion = load(rp_file);
        RPDiff=diff(HMotion);
        RPDiff=[zeros(1,6);RPDiff];
        RPDiffSphere=RPDiff;
        RPDiffSphere(:,4:6)=RPDiffSphere(:,4:6)*50;
        FD=sum(abs(RPDiffSphere),2);
        TemporalMask=ones(length(FD),1);
        Index=find(FD > FDThreshold);
        TemporalMask(Index)=0;

        if ~all(TemporalMask)
            AllVolume = AllVolume(find(TemporalMask),:); %'cut'
            nDimTimePoints = size(AllVolume,1);
        end
    end


    %% Save file
    if ~exist(save_dir,'dir')
        mkdir(save_dir);
    end
    
    AResultFilename = 'denoised_rest.nii';
    data_save = reshape(AllVolume', [nDim1 nDim2 nDim3 nDimTimePoints]);
    header_save.fname = AResultFilename;
    header_save.dt=[16,0];
    cd(save_dir);
    y_Write(data_save, header_save, AResultFilename);
    