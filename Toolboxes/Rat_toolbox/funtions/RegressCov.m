function [b,r]=RegressCov(y,X)
[n,ncolX]=size(X);
[Q,R,perm]=qr(X,0);
p=sum(abs(diag(R))>max(n,ncolX)*eps(R(1)));
if p<ncolX,
    R=R(1:p,1:p);
    Q=Q(:,1:p);
    perm=perm(1:p);
end
b=[];
b(perm,:)=R \ (Q'*y);
yhat=X*b;                     % Predicted responses at each data point.
r=y-yhat;                     % Residuals.