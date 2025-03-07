% Find (significant) edge result after GRETNA Connectional Metric Comparison
% Adapted from Siying Tech's scripts
% Zhaoyu Deng, zhaoyu_deng@163.com
% 2025/03/06

% Firstly change directory to output dir in GRETNA Connectional Metric Comparison
% After finding, you can save variables
clear; clc;

%% Gretna edge result(FDR/FWE/none)
pnet=load('Edge_PNet.txt');
pthrd=load('Edge_PThrd.txt');
tnet=load('Edge_TNet.txt');
[m,n] = find(triu(pnet<=pthrd,1));
p = [];
t = [];
for i=1:size(m)
    p(i,1) = pnet(m(i),n(i));
    t(i,1) = tnet(m(i),n(i));
end
res = [m,n,p,t];

%% Gretna edge result(nbs)
comp=load('Edge_Neg_Comnet_P=0.00990099.txt');
pnet=load('Edge_PNet.txt');
[m,n,t]=find(triu(comp,1));
[m,n,p]=find(triu(comp~=0,1).*pnet);
re=[m,n,p,t];
