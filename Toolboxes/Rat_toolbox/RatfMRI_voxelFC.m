function RatfMRI_voxelFC(nii_file,brainmask,seedmask,save_dir)
AllVolume=nii_file;
ROIDef={seedmask};
MaskData=spm_read_vols(spm_vol(brainmask));
OutputName=fullfile(save_dir,'FCBrain.nii');
y_SCA(AllVolume, ROIDef, OutputName, MaskData);
end



function [FCBrain, Header] = y_SCA(AllVolume, ROIDef, OutputName, MaskData, IsMultipleLabel, IsNeedDetrend, Band, TR, TemporalMask, ScrubbingMethod, ScrubbingTiming, Header, CUTNUMBER)
% [FCBrain, Header] = y_SCA(AllVolume, ROIDef, OutputName, MaskData, IsMultipleLabel, IsNeedDetrend, Band, TR, TemporalMask, ScrubbingMethod, ScrubbingTiming, Header, CUTNUMBER)
% Calculate Functional Connectivity by Seed based Correlation Anlyasis
% Input:
% 	AllVolume		-	4D data matrix (DimX*DimY*DimZ*DimTimePoints) or the directory of 3D image data file or the filename of one 4D data file
%   ROIDef              ROI definition, cells. Each cell could be:
%                       -1. 3D mask martrix (DimX*DimY*DimZ)
%                       -2. Series matrix (DimTimePoints*1)
%                       -3. REST Sphere Definition
%                       -4. .img/.nii/.nii.gz mask file
%                       -5. .txt Series. If multiple columns, when IsMultipleLabel==1: each column is a seperate seed series
%                                                             when IsMultipleLabel==0: average all the columns and take the mean series (one column) as seed series
%	OutputName  	-	Output filename
% 	MaskData		-   The Brain Mask matrix (DimX*DimY*DimZ) or the Brain Mask file name
%   IsMultipleLabel -   1: There are multiple labels in the ROI mask file. Will extract each of them. (e.g., for aal.nii, extract all the time series for 116 regions)
%                       0 (default): All the non-zero values will be used to define the only ROI
%   IsNeedDetrend   -   0: Dot not detrend; 1: Use Matlab's detrend
%   Band            -   Temporal filter band: matlab's ideal filter e.g. [0.01 0.08]
%   TR              -   The TR of scanning. (Used for filtering.)
%   TemporalMask    -   Temporal mask for scrubbing (DimTimePoints*1)
%                   -   Empty (blank: '' or []) means do not need scrube. Then ScrubbingMethod and ScrubbingTiming can leave blank
%   ScrubbingMethod -   The methods for scrubbing.
%                       -1. 'cut': discarding the timepoints with TemporalMask == 0
%                       -2. 'nearest': interpolate the timepoints with TemporalMask == 0 by Nearest neighbor interpolation 
%                       -3. 'linear': interpolate the timepoints with TemporalMask == 0 by Linear interpolation
%                       -4. 'spline': interpolate the timepoints with TemporalMask == 0 by Cubic spline interpolation
%                       -5. 'pchip': interpolate the timepoints with TemporalMask == 0 by Piecewise cubic Hermite interpolation
%   ScrubbingTiming -   The timing for scrubbing.
%                       -1. 'BeforeFiltering': scrubbing (and interpolation, if) before detrend (if) and filtering (if).
%                       -2. 'AfterFiltering': scrubbing after filtering, right before extract ROI TC and FC analysis
%   Header          -   If AllVolume is given as a 4D Brain matrix, then Header should be designated.
%   CUTNUMBER       -   Cut the data into pieces if small RAM memory e.g. 4GB is available on PC. It can be set to 1 on server with big memory (e.g., 50GB).
%                       default: 10
% Output:
%	FCBrain         -   the FC of the final ROI (Only Use it correctly with only one seed)
%   Header          -   The NIfTI Header
%   All the FC images will be output as where OutputName specified.
%-----------------------------------------------------------
% Written by YAN Chao-Gan 120216 based on fc.m.
% The Nathan Kline Institute for Psychiatric Research, 140 Old Orangeburg Road, Orangeburg, NY 10962, USA
% Child Mind Institute, 445 Park Avenue, New York, NY 10022, USA
% The Phyllis Green and Randolph Cowen Institute for Pediatric Neuroscience, New York University Child Study Center, New York, NY 10016, USA
% ycg.yan@gmail.com

if ~exist('IsMultipleLabel','var')
    IsMultipleLabel = 0;
end

if ~exist('CUTNUMBER','var')
    CUTNUMBER = 10;
end

theElapsedTime =cputime;
fprintf('\n\t Calculating Functional Connectivity by Seed based Correlation Anlyasis...');

if ~isnumeric(AllVolume)
    [AllVolume,VoxelSize,theImgFileList, Header] =y_ReadAll(AllVolume);
end


[nDim1 nDim2 nDim3 nDimTimePoints]=size(AllVolume);
BrainSize = [nDim1 nDim2 nDim3];
VoxelSize = sqrt(sum(Header.mat(1:3,1:3).^2));


if ischar(MaskData)
    fprintf('\nLoad mask "%s".\n', MaskData);
    if ~isempty(MaskData)
        [MaskData,MaskVox,MaskHead]=y_ReadRPI(MaskData);
        if ~all(size(MaskData)==[nDim1 nDim2 nDim3])
            error('The size of Mask (%dx%dx%d) doesn''t match the required size (%dx%dx%d).\n',size(MaskData), [nDim1 nDim2 nDim3]);
        end
        MaskData = double(logical(MaskData));
    else
        MaskData=ones(nDim1,nDim2,nDim3);
    end
end

% Convert into 2D
AllVolume=reshape(AllVolume,[],nDimTimePoints)';
% AllVolume=permute(AllVolume,[4,1,2,3]); % Change the Time Course to the first dimention
% AllVolume=reshape(AllVolume,nDimTimePoints,[]);

MaskDataOneDim=reshape(MaskData,1,[]);
MaskIndex = find(MaskDataOneDim);
AllVolume=AllVolume(:,MaskIndex);

% Scrubbing
if exist('TemporalMask','var') && ~isempty(TemporalMask) && ~strcmpi(ScrubbingTiming,'AfterFiltering')
    if ~all(TemporalMask)
        AllVolume = AllVolume(find(TemporalMask),:); %'cut'
        if ~strcmpi(ScrubbingMethod,'cut')
            xi=1:length(TemporalMask);
            x=xi(find(TemporalMask));
            AllVolume = interp1(x,AllVolume,xi,ScrubbingMethod);
        end
        nDimTimePoints = size(AllVolume,1);
    end
end


% Detrend
if exist('IsNeedDetrend','var') && IsNeedDetrend==1
    %AllVolume=detrend(AllVolume);
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

% Filtering
if exist('Band','var') && ~isempty(Band)
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



% Scrubbing after filtering
if exist('TemporalMask','var') && ~isempty(TemporalMask) && strcmpi(ScrubbingTiming,'AfterFiltering')
    if ~all(TemporalMask)
        AllVolume = AllVolume(find(TemporalMask),:); %'cut'
        if ~strcmpi(ScrubbingMethod,'cut')
            xi=1:length(TemporalMask);
            x=xi(find(TemporalMask));
            AllVolume = interp1(x,AllVolume,xi,ScrubbingMethod);
        end
        nDimTimePoints = size(AllVolume,1);
    end
end


% Extract the Seed Time Courses

SeedSeries = [];
MaskROIName=[];

for iROI=1:length(ROIDef)
    IsDefinedROITimeCourse =0;
    if strcmpi(int2str(size(ROIDef{iROI})),int2str([nDim1, nDim2, nDim3]))  %ROI Data
        MaskROI = ROIDef{iROI};
        MaskROIName{iROI} = sprintf('Mask Matrix definition %d',iROI);
    elseif size(ROIDef{iROI},1) == nDimTimePoints %Seed series %strcmpi(int2str(size(ROIDef{iROI})),int2str([nDimTimePoints, 1])) %Seed series
        SeedSeries{1,iROI} = ROIDef{iROI};
        IsDefinedROITimeCourse =1;
        MaskROIName{iROI} = sprintf('Seed Series definition %d',iROI);
    elseif strcmpi(int2str(size(ROIDef{iROI})),int2str([1, 4]))  %Sphere ROI definition: CenterX, CenterY, CenterZ, Radius
        MaskROI = y_Sphere(ROIDef{iROI}(1:3), ROIDef{iROI}(4), Header);
        MaskROIName{iROI} = sprintf('Sphere definition (CenterX, CenterY, CenterZ, Radius): %g %g %g %g.',ROIDef{iROI});
    elseif exist(ROIDef{iROI},'file')==2	% Make sure the Definition file exist
        [pathstr, name, ext] = fileparts(ROIDef{iROI});
        if strcmpi(ext, '.txt'),
            TextSeries = load(ROIDef{iROI});
            if IsMultipleLabel == 1
                for iElement=1:size(TextSeries,2)
                    MaskROILabel{1,iROI}{iElement,1} = ['Column ',num2str(iElement)];
                end
                SeedSeries{1,iROI} = TextSeries;
            else
                SeedSeries{1,iROI} = mean(TextSeries,2);
            end
            IsDefinedROITimeCourse =1;
            MaskROIName{iROI} = ROIDef{iROI};
        elseif strcmpi(ext, '.img') || strcmpi(ext, '.nii') || strcmpi(ext, '.gz')
            %The ROI definition is a mask file
            
            MaskROI=y_ReadRPI(ROIDef{iROI});
            if ~strcmpi(int2str(size(MaskROI)),int2str([nDim1, nDim2, nDim3]))
                error(sprintf('\n\tMask does not match.\n\tMask size is %dx%dx%d, not same with required size %dx%dx%d',size(MaskROI), [nDim1, nDim2, nDim3]));
            end

            MaskROIName{iROI} = ROIDef{iROI};
        else
            error(sprintf('Wrong ROI file type, please check: \n%s', ROIDef{iROI}));
        end
        
    else
        error(sprintf('File doesn''t exist or wrong ROI definition, please check: %s.\n', ROIDef{iROI}));
    end

    if ~IsDefinedROITimeCourse
        % Speed up! YAN Chao-Gan 101010.
        MaskROI=reshape(MaskROI,1,[]);
        MaskROI=MaskROI(MaskIndex); %Apply the brain mask
        
        if IsMultipleLabel == 1
            Element = unique(MaskROI);
            Element(find(isnan(Element))) = []; % ignore background if encoded as nan. Suggested by Dr. Martin Dyrba
            Element(find(Element==0)) = []; % This is the background 0
            SeedSeries_MultipleLabel = zeros(nDimTimePoints,length(Element));
            for iElement=1:length(Element)
                
                SeedSeries_MultipleLabel(:,iElement) = mean(AllVolume(:,find(MaskROI==Element(iElement))),2);
                
                MaskROILabel{1,iROI}{iElement,1} = num2str(Element(iElement));

            end
            SeedSeries{1,iROI} = SeedSeries_MultipleLabel;
        else
            SeedSeries{1,iROI} = mean(AllVolume(:,find(MaskROI)),2);
        end
    end
end


%Merge the seed series cell into seed series matrix
SeedSeries = double(cell2mat(SeedSeries)); %Suggested by H. Baetschmann.  % SeedSeries = cell2mat(SeedSeries);


%Save the ROI averaged time course to disk for further study
[pathstr, name, ext] = fileparts(OutputName);

save([fullfile(pathstr,['ROI_', name]), '.mat'], 'SeedSeries')
save([fullfile(pathstr,['ROI_', name]), '.txt'], 'SeedSeries', '-ASCII', '-DOUBLE','-TABS')

%Write the order key file as .tsv
fid = fopen([fullfile(pathstr,['ROI_OrderKey_', name]), '.tsv'],'w');
if IsMultipleLabel == 1
    if size(MaskROILabel,2) < length(ROIDef) %YAN Chao-Gan, 131124. To avoid if the labels of the last ROI has been defined.
        MaskROILabel{1,length(ROIDef)} = []; % Force the undefined cells to empty
    end
    fprintf(fid,'Order\tLabel in Mask\tROI Definition\n');
    iOrder = 1;
    for iROI=1:length(ROIDef)
        if isempty(MaskROILabel{1,iROI})
            fprintf(fid,'%d\t\t%s\n',iOrder,MaskROIName{iROI});
            iOrder = iOrder + 1;
        else
            for iElement=1:length(MaskROILabel{1,iROI})
                fprintf(fid,'%d\t%s\t%s\n',iOrder,MaskROILabel{1,iROI}{iElement,1},MaskROIName{iROI});
                iOrder = iOrder + 1;
            end
        end
    end
else
    fprintf(fid,'Order\tROI Definition\n');
    for iROI=1:length(ROIDef)
        fprintf(fid,'%d\t%s\n',iROI,MaskROIName{iROI});
    end
end
fclose(fid);



% FC calculation
AllVolume = AllVolume-repmat(mean(AllVolume),size(AllVolume,1),1);
AllVolumeSTD= squeeze(std(AllVolume, 0, 1));
AllVolumeSTD(find(AllVolumeSTD==0))=inf;

SeedSeries=SeedSeries-repmat(mean(SeedSeries),size(SeedSeries,1),1);
SeedSeriesSTD=squeeze(std(SeedSeries,0,1));

Header.pinfo = [1;0;0];
Header.dt    =[16,0];

for iROI=1:size(SeedSeries,2)
    
    FC=SeedSeries(:,iROI)'*AllVolume/(nDimTimePoints-1);
    FC=(FC./AllVolumeSTD)/SeedSeriesSTD(iROI);
    
    FCBrain=zeros(size(MaskDataOneDim));
    FCBrain(1,MaskIndex)=FC;
    FCBrain=reshape(FCBrain,nDim1, nDim2, nDim3);
    
    %Also produce the results after Fisher's r to z transformation
    zFCBrain = (0.5 * log((1 + FCBrain)./(1 - FCBrain))) .* (MaskData~=0);

    [pathstr, name, ext] = fileparts(OutputName);
    if size(SeedSeries, 2)>1
        %Save every maps from result maps
        y_Write(FCBrain,Header,[fullfile(pathstr,['ROI',num2str(iROI),name, ext])]);
        y_Write(zFCBrain,Header,[fullfile(pathstr,['zROI',num2str(iROI),name, ext])]);
    elseif size(SeedSeries, 2)==1,
        %Save one map
        y_Write(FCBrain,Header,[fullfile(pathstr,[name, ext])]);
        y_Write(zFCBrain,Header,[fullfile(pathstr,['z',name, ext])]);
    end
end


theElapsedTime = cputime - theElapsedTime;
fprintf('\n\t Calculating Functional Connectivity by Seed based Correlation Anlyasis finished, elapsed time: %g seconds.\n', theElapsedTime);
end