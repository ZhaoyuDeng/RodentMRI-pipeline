function JQ_multi_Vs(fname,mul)
% written by Qiu Jicheng,2021/09/15,qiu.jicheng@outlook.com
M=spm_get_space(fname);
M=M*mul;
M(4,4)=1;
spm_get_space(fname,M);

Mfile=strrep(fname,'.nii','.mat');
if exist(Mfile,'file')
    delete(Mfile);
end
V=spm_vol(fname);
X=spm_read_vols(V);
for i=1:numel(V)
    spm_write_vol(V(i),squeeze(X(:,:,:,i)));
end