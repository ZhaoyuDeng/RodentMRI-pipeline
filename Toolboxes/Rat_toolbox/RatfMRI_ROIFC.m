function RatfMRI_ROIFC(nii_file,atlasfile,save_dir)
disp(sprintf('Computing ROI FC for %s ...\n',nii_file));
ts=JQ_extractROIts(nii_file,atlasfile,'mean');
corrmat=corr(ts);
zcorrmat=atanh(corrmat);
zcorrmat(find(diag(diag(zcorrmat))))=0;
save_name=fullfile(save_dir,'FCmat.txt');
zsave_name=fullfile(save_dir,'zFCmat.txt');
save(save_name,'corrmat','-ascii');
save(zsave_name,'zcorrmat','-ascii');



function ts=JQ_extractROIts(datafile,atlasfile,method)
%%written by JQ,2019/11/9,qiu.jicheng@icloud.com
%datafile - nii or nii directory for data to extract
%atlasfile - nii file for n-ary or binary mask
%method - srting for extract method :'mean' or 'pca' or 'sum'
%% read data
if ~exist('method','var')
    method='mean';
end
if iscell(datafile)
    for i = 1:length(datafile)
        V(i)=spm_vol(datafile{i});
    end
    data=spm_read_vols(V);
elseif exist('datafile','dir') | exist(datafile,'dir')
    if isunix
        system(['rm ',fullfile(datafile,'._*')]);
    end
    filelist=dir(fullfile(datafile,'*.nii'));
    if isempty(filelist)
        filelist=dir(fullfile(datafile,'*.gz'));
    end
    for i = 1:length(filelist)
        V(i)=spm_vol(fullfile(datafile,filelist(i).name));
    end
    data=spm_read_vols(V);
else
    data=spm_read_vols(spm_vol(datafile));
end
data(isnan(data))=0;
data(isinf(data))=0;
%% read atlas
ROI=spm_read_vols(spm_vol(atlasfile));
ind=unique(ROI);
outind=logical(isnan(ind)+isinf(ind)+(ind==0));
ind(outind)=[]; 
%% extract ts
if length(size(data))==4
    ts= zeros(size(data,4),length(ind));
    data=reshape(data,[],size(data,4));
    data=data';
    ROI=reshape(ROI,1,[]);
    if length(ROI)~=size(data,2)
        error('Data and mask not match')
    end
    if strcmp(method,'mean')
        for i=1:length(ind)
            ts(:,i) = mean(data(:,ROI==ind(i)),2);
        end
    elseif strcmp(method,'pca')
    	for i=1:length(ind)
            [~,score,~] = pca(data(:,ROI==ind(i)));
            ts(:,i) = score(:,1);
        end
    elseif strcmp(method,'sum')
        for i=1:length(ind)
            ts(:,i) = sum(data(:,ROI==ind(i)),2);
        end
    end
elseif length(size(data))==3
    ts= zeros(1,length(ind));
    data=reshape(data,[],1);
    data=data';
    ROI=reshape(ROI,1,[]);
    if strcmp(method,'mean')
        for i=1:length(ind)
            ts(1,i) = mean(data(ROI==ind(i)));
        end
    elseif strcmp(method,'pca')
    	error('must be a 4D data')
    elseif strcmp(method,'sum')
        for i=1:length(ind)
            ts(:,i) = sum(data(:,ROI==ind(i)));
        end
    end

end