function [dipout] = minimumnormestimate(dip, grad, vol, dat, varargin)

% MINIMUMNORMESTIMATE computes a linear estimate of the current in a
% distributed source model.
% 
% Use as
%   [dipout] = minimumnormestimate(dip, grad, vol, dat, ...)
%
% Optional input arguments should come in key-value pairs and can include
%   'noisecov'         = Nchan x Nchan matrix with noise covariance
%   'noiselambda'      = scalar value, regularisation parameter for the noise
%                        covariance matrix. (default=0)
%   'sourcecov'        = Nsource x Nsource matrix with source covariance
%                        (can be empty, the default will then be identity)
%   'lambda'           = scalar, regularisation parameter (can be empty, 
%                        it will then be estimated from snr) 
%  'snr'               = scalar, signal to noise ratio
%  'reducerank'        = reduce the leadfield rank, can be 'no' or a number
%                        (e.g. 2) 
%  'normalize'         = normalize the leadfield
%  'normalizeparam'    = parameter for depth normalization (default = 0.5)
%  'keepfilter'        = 'no' or 'yes', keep the spatial filter in the
%                        output
%  'prewhiten'         = 'no' or 'yes', prewhiten the leadfield matrix with
%                        the noise covariance matrix C.
%  'scalesourcecov'    = 'no' or 'yes', scale the source covariance matrix R
%                        such that trace(leadfield*R*leadfield')/trace(C)=1
%
% Note that leadfield normalization (depth regularisation) should be done
% by scaling the leadfields outside this function, e.g. in
% prepare_leadfield. Note also that with precomputed leadfields the
% normalization parameters will not have an effect.
%
% This implements
% * Dale AM, Liu AK, Fischl B, Buckner RL, Belliveau JW, Lewine JD,
%   Halgren E (2000): Dynamic statistical parametric mapping: combining
%   fMRI and MEG to produce high-resolution spatiotemporal maps of
%   cortical activity. Neuron 26:55-67.
% * Arthur K. Liu, Anders M. Dale, and John W. Belliveau  (2002): Monte
%   Carlo Simulation Studies of EEG and MEG Localization Accuracy.
%   Human Brain Mapping 16:47-62.
% * Fa-Hsuan Lin, Thomas Witzel, Matti S. Hamalainen, Anders M. Dale,
%   John W. Belliveau, and Steven M. Stufflebeam (2004): Spectral
%   spatiotemporal imaging of cortical oscillations and interactions
%   in the human brain.  NeuroImage 23:582-595.

% TODO implement the following options
% - keepleadfield

% Copyright (C) 2004-2008, Robert Oostenveld
%
% This file is part of FieldTrip, see http://www.ru.nl/neuroimaging/fieldtrip
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.
%
% $Id: minimumnormestimate.m 9585 2014-05-22 18:52:26Z jansch $

% ensure that these are row-vectors
dip.inside  = dip.inside(:)';
dip.outside = dip.outside(:)';

% get the optional inputs for the MNE method according to Dale et al 2000, and Liu et al. 2002
noisecov       = ft_getopt(varargin, 'noisecov');
sourcecov      = ft_getopt(varargin, 'sourcecov');
lambda         = ft_getopt(varargin, 'lambda');  % can be empty, it will then be estimated based on SNR
noiselambda    = ft_getopt(varargin, 'noiselambda', []);
snr            = ft_getopt(varargin, 'snr');     % is used to estimate lambda if lambda is not specified

% these settings pertain to the forward model, the defaults are set in compute_leadfield
reducerank     = ft_getopt(varargin, 'reducerank');
normalize      = ft_getopt(varargin, 'normalize');
normalizeparam = ft_getopt(varargin, 'normalizeparam', 0.5);
keepfilter     = istrue(ft_getopt(varargin, 'keepfilter', false));
dowhiten       = istrue(ft_getopt(varargin, 'prewhiten',  false));
doscale        = istrue(ft_getopt(varargin, 'scalesourcecov', false));
hasleadfield   = isfield(dip, 'leadfield');
hasfilter      = isfield(dip, 'filter');

if isempty(lambda) && isempty(snr) && ~isfield(dip, 'filter')
  error('either lambda or snr should be specified');
elseif ~isempty(lambda) && ~isempty(snr)
  error('either lambda or snr should be specified, not both');
end

%if ~isempty(snr) && doscale
%  error('scaling of the source covariance in combination with a specified snr parameter is not allowed');
%end

% compute leadfield
if hasfilter
  % it does not matter whether the leadfield is there or not, it will not be used
  fprintf('using pre-computed spatial filter: some of the specified options will not have an effect\n');
elseif hasleadfield
  % using the computed leadfields
  fprintf('using pre-computed leadfields: some of the specified options will not have an effect\n');
else
  fprintf('computing forward model\n');
  if isfield(dip, 'mom')
    for i=dip.inside
      % compute the leadfield for a fixed dipole orientation
      dip.leadfield{i} = ft_compute_leadfield(dip.pos(i,:), grad, vol, 'reducerank', reducerank, 'normalize', normalize, 'normalizeparam', normalizeparam) * dip.mom(:,i);
    end
  else
    for i=dip.inside
      % compute the leadfield
      dip.leadfield{i} = ft_compute_leadfield(dip.pos(i,:), grad, vol, 'reducerank', reducerank, 'normalize', normalize, 'normalizeparam', normalizeparam);
    end
  end
  for i=dip.outside
    dip.leadfield{i} = nan;
  end
end

% compute the spatial filter
if ~hasfilter
  Nchan = size(dip.leadfield{dip.inside(1)},1);
  
  % count the number of leadfield components for each source
  Nsource = 0;
  for i=dip.inside
    Nsource = Nsource + size(dip.leadfield{i}, 2);
  end
  
  % concatenate the leadfield components of all sources into one large matrix
  lf = zeros(Nchan, Nsource);
  n = 1;
  for i=dip.inside
    cbeg = n;
    cend = n + size(dip.leadfield{i}, 2) - 1;
    lf(:,cbeg:cend) = dip.leadfield{i};
    n = n + size(dip.leadfield{i}, 2);
  end
  
  % compute the inverse of the forward model, this is where prior information
  % on source and noise covariance would be useful
  if isempty(noisecov)
    % use an unregularised minimum norm solution, i.e. using the Moore-Penrose pseudoinverse
    warning('computing a unregularised minimum norm solution. This typically does not work due to numerical accuracy problems');
    w = pinv(lf);
  elseif ~isempty(noisecov)
    fprintf('computing the solution where the noise covariance is used for regularisation\n'); 
    % the noise covariance has been given and can be used to regularise the solution
    if isempty(sourcecov)
      sourcecov = speye(Nsource);
    end
    % rename some variables for consistency with the publications
    A = lf;
    R = sourcecov;
    C = noisecov;
    
    if dowhiten,
      fprintf('prewhitening the leadfields using the noise covariance\n');
      
      % compute the prewhitening matrix
      if ~isempty(noiselambda)
        fprintf('using a regularized noise covariance matrix\n');
        % note: if different channel types are present, one should probably load the diagonal with channel-type specific stuff
        [U,S,V] = svd(C+eye(size(C))*noiselambda);
      else
        [U,S,V] = svd(C);
      end
      
      Tol     = 1e-12;
      diagS   = diag(S);
      sel     = find(diagS>Tol.*diagS(1));
      P       = diag(1./sqrt(diag(S(sel,sel))))*U(:,sel)'; % prewhitening matrix
      A       = P*A; % prewhitened leadfields 
      C       = eye(size(P,1)); % prewhitened noise covariance matrix
    end
    
    if doscale
      % estimate sourcecov such that trace(ARA')/trace(C) = 1 (see
      % http://martinos.org/mne/manual/mne.html. In the case of prewhitening
      % C reduces to I (and then lambda^2 ~ 1/SNR); note that in mixed
      % channel type covariance matrices prewhitening should be applied in
      % order for this to make sense (otherwise the diagonal elements of C
      % have different units)
      fprintf('scaling the source covariance\n');
      scale = trace(A*(R*A'))/trace(C);
      R     = R./scale;
    end
    
    if ~isempty(snr)
      % the regularisation parameter can be estimated from the noise covariance,
      % see equation 6 in Lin et al. 2004
      lambda = trace(A * R * A')/(trace(C)*snr^2);
    end
    
    %% equation 5 from Lin et al 2004 (this implements Dale et al 2000, and Liu et al. 2002)
    %denom = (A*R*A'+(lambda^2)*C);
    %if cond(denom)<1e12
    %  w = R * A' / denom;
    %else
    %  fprintf('taking pseudo-inverse due to large condition number\n');
    %  w = R * A' * pinv(denom);
    %end
    
    % as documented on MNE website, this is replacing the part of the code above, it gives
    % more stable results numerically.
    Rc      = chol(R, 'lower');
    [U,S,V] = svd(A * Rc, 'econ');
    s  = diag(S);
    ss = s ./ (s.^2 + lambda);
    w  = Rc * V * diag(ss) * U';
    
    % unwhiten the filters to bring them back into signal subspace
    if dowhiten
      w = w*P;
    end
       
  end
  
  % for each of the timebins, estimate the source strength
  mom = w * dat;
  
  % re-assign the estimated source strength over the inside and outside dipoles
  n = 1;
  for i=dip.inside
    cbeg = n;
    cend = n + size(dip.leadfield{i}, 2) - 1;
    dipout.mom{i} = mom(cbeg:cend,:);
    n = n + size(dip.leadfield{i}, 2);
  end
  dipout.mom(dip.outside) = {nan};

elseif hasfilter
  
  % use the spatial filters from the data
  dipout.mom = cell(size(dip.pos,1),1);
  for i=dip.inside
    dipout.mom{i} = dip.filter{i} * dat;
  end
  dipout.mom(dip.outside) = {nan};
  
end

% for convenience also compute power (over the three orientations) at each location and for each time
dipout.pow = nan( size(dip.pos,1), size(dat,2));
for i=dip.inside
  dipout.pow(i,:) = sum(dipout.mom{i}.^2, 1);
end

% add other descriptive information to the output source model
dipout.pos     = dip.pos;
dipout.inside  = dip.inside;
dipout.outside = dip.outside;

% deal with keepfilter option
if keepfilter && ~hasfilter
  % spatial filters have been computed, store them in the output
  % re-assign spatial filter to conventional 1 cell per dipole location
  n = 1;
  for i=dip.inside(:)'
    cbeg = n;
    cend = n + size(dip.leadfield{i}, 2) - 1;
    dipout.filter{i} = w(cbeg:cend,:);
    n    = n + size(dip.leadfield{i}, 2);
  end
  dipout.filter(dip.outside)  = {nan};
  
elseif keepfilter
  dipout.filter = dip.filter;
end

% deal with noise covariance
if ~isempty(noisecov) && ~hasfilter
  
  % compute estimate of the projected noise
  n = 1;
  for i=dip.inside(:)'
    cbeg = n;
    cend = n + size(dip.leadfield{i}, 2) - 1;
    dipout.noisecov{i} = w(cbeg:cend,:)*noisecov*w(cbeg:cend,:)';
    n    = n + size(dip.leadfield{i}, 2);
  end
  dipout.noisecov(dip.outside) = {nan};

elseif ~isempty(noisecov)
  
  % compute estimate of the projected noise
  for i=dip.inside(:)'
    dipout.noisecov{i} = dipout.filter{i}*noisecov*dipout.filter{i}';
  end
  dipout.noisecov(dip.outside) = {nan};

end
