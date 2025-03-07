function [data] = ft_regressconfound(cfg, datain)

% FT_REGRESSCONFOUND estimates the regression weight of a set of confounds
% using a General Linear Model (GLM) and removes the estimated contribution
% from the single-trial data.
%
% Use as
%   timelock = ft_regressconfound(cfg, timelock)
% or as
%   freq     = ft_regressconfound(cfg, freq)
% or as
%   source   = ft_regressconfound(cfg, source)
%
% where timelock, freq, or, source come from FT_TIMELOCKANALYSIS,
% FT_FREQANALYSIS, or FT_SOURCEANALYSIS respectively, with keeptrials = 'yes'
%
% The cfg argument is a structure that should contain
%   cfg.confound    = matrix, [Ntrials X Nconfounds], may not contain NaNs
%
% The following configuration options are supported:
%   cfg.reject      = vector, [1 X Nconfounds], listing the confounds that
%                     are to be rejected (default = 'all')
%   cfg.normalize   = string, 'yes' or 'no', normalization to
%                     make the confounds orthogonal (default = 'yes')
%   cfg.statistics  = string, 'yes' or 'no', whether to add the statistics
%                     on the regression weights to the output (default = 'no')
%   cfg.model       = string, 'yes' or 'no', whether to add the model to
%                     the output (default = 'no')
%   cfg.ftest       = string array, {N X Nconfounds}, to F-test whether
%                     the full model explains more variance than reduced models
%                     (e.g. {'1 2'; '3 4'; '5'} where iteratively the added value of
%                     regressors 1 and 2, and then 3 and 4, etc., are tested)
%
% This method is described by Stolk et al., Online and offline tools for head 
% movement compensation in MEG. NeuroImage, 2012.
%
% To facilitate data-handling and distributed computing you can use
%   cfg.inputfile   =  ...
%   cfg.outputfile  =  ...
% If you specify one of these (or both) the input data will be read from a *.mat
% file on disk and/or the output data will be written to a *.mat file. These mat
% files should contain only a single variable, corresponding with the
% input/output structure.
%
% See also FT_REJECTCOMPONENT, FT_REJECTARTIFACT

% Copyright (C) 2011, Arjen Stolk, Robert Oostenveld, Lennart Verhagen
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
% $Id: ft_regressconfound.m 9520 2014-05-14 09:33:28Z roboos $

revision = '$Id: ft_regressconfound.m 9520 2014-05-14 09:33:28Z roboos $';

% do the general setup of the function
ft_defaults
ft_preamble init
ft_preamble provenance
ft_preamble trackconfig
ft_preamble debug
ft_preamble loadvar datain

% the abort variable is set to true or false in ft_preamble_init
if abort
  return
end

% check if the input data is valid for this function
datain = ft_checkdata(datain, 'datatype', {'timelock', 'freq', 'source'}, 'feedback', 'yes', 'hastrials', 'yes');

% ensure that the required options are present
cfg = ft_checkconfig(cfg, 'required', {'confound'}, 'renamed', {'Ftest','ftest'});

% confound specification
regr      = ft_getopt(cfg, 'confound');  % there is no default value
if ~isempty(find(isnan(regr)))
  error('the confounds may not contain NaNs');
end
nconf     = size(regr,2);
conflist  = 1:nconf;
if ~isfield(cfg, 'reject') || strcmp(cfg.reject, 'all') % default
  cfg.reject = conflist(1:end); % to be removed
else
  cfg.reject = intersect(conflist, cfg.reject); % to be removed
end

fprintf('removing confound %s \n', num2str(cfg.reject));
kprs = setdiff(conflist, cfg.reject); % to be kept
fprintf('keeping confound %s \n', num2str(kprs));

% confound normalization for orthogonality
if ~isfield(cfg, 'normalize') || stcrmp(cfg.normalize, 'yes')
  fprintf('normalizing the confounds, except the constant \n');
  for c = 1:nconf
    SD = std(regr(:,c),0,1);
    if SD == 0
      fprintf('confound %s is a constant \n', num2str(c));
    else
      regr(:,c) = (regr(:,c) - mean(regr(:,c))) / SD;
    end
    clear SD;
  end
elseif stcrmp(cfg.normalize, 'no')
  fprintf('skipping normalization procedure \n');
end

% determine datatype
isfreq     = ft_datatype(datain, 'freq');
istimelock = ft_datatype(datain, 'timelock');
issource   = ft_datatype(datain, 'source');

% input handling
if istimelock
  switch datain.dimord
    case {'rpt_chan_time', 'subj_chan_time'}
      
      % descriptives
      nrpt  = size(datain.trial, 1);
      nchan = size(datain.trial, 2);
      ntime = size(datain.trial, 3);
      
      % initialize output variable
      dataout       = datain;
      
      if nrpt~=size(regr,1)
        error('the size of your confound matrix does not match with the number of trials/subjects');
      end
      
      % get the data on which the contribution of the confounds has to be estimated
      dat = reshape(datain.trial, [nrpt, nchan*ntime]);
      
    otherwise
      error('unsupported timelock dimord "%s"', datain.dimord);
  end % switch
  
elseif isfreq
  switch datain.dimord
    case {'rpt_chan_freq_time', 'subj_chan_freq_time', 'rpttap_chan_freq_time', 'rpt_chan_freq', 'subj_chan_freq', 'rpttap_chan_freq'}
      
      % descriptives
      nrpt  = size(datain.powspctrm, 1);
      nchan = size(datain.powspctrm, 2);
      nfreq = size(datain.powspctrm, 3);
      ntime = size(datain.powspctrm, 4); % this will be a singleton dimension in case there is no time
      
      % initialize output variable
      dataout       = datain;
      
      if nrpt~=size(regr,1)
        error('the size of your confound matrix does not match with the number of trials/subjects');
      end
      
      % get the data on which the contribution of the confounds has to be estimated
      dat = reshape(datain.powspctrm, [nrpt, nchan*nfreq*ntime]);
      
    otherwise
      error('unsupported freq dimord "%s"', datain.dimord);
  end % switch
  
elseif issource

  % ensure that the source structure contains inside/outside specification
  datain = ft_checkdata(datain, 'datatype', 'source', 'hasinside', 'yes');

  % descriptives
  nrpt    = size(datain.trial, 2);
  nvox    = size(datain.pos, 1);
  ninside = size(datain.inside, 2);
  
  % initialize output variable
  dataout       = datain;
  
  if nrpt~=size(regr,1)
    error('the size of your confound matrix does not match with the number of trials/subjects');
  end
  
  % get the data on which the contribution of the confounds has to be estimated
  dat = zeros(nrpt, ninside);
  for i = 1:nrpt
    dat(i,:) = datain.trial(1,i).pow(datain.inside); % reshape to [nrpt, nvox]
  end
  
else
  error('the input data should be either timelock, freq, or source with trials')
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% GLM MODEL
%   Y = X * B + err, where Y is data, X is the model, and B are beta's
% which means
%   Best = X\Y ('matrix division', which is similar to B = inv(X)*Y)
% or when presented differently
%   Yest = X * Best
%   Yest = X * X\Y
%   Yclean = Y - Yest (the true 'clean' data is the recorded data 'Y' -
%   the data containing confounds 'Yest')
%   Yclean = Y - X * X\Y
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% estimate and remove the confounds
fprintf('estimating the regression weights and removing the confounds \n');
if isempty(find(isnan(dat))) % if there are no NaNs, process all at once
  
	beta = regr\dat;                                                        % B = X\Y
  
else % otherwise process per colum set as defined by the nan distribution 
  
  [u,i,j] = unique(~isnan(dat)','rows','first'); % find unique rows
  uniquecolumns = u'; % unique column types
  Nuniques = numel(i); % number of unique types
  beta_temp = NaN(Nuniques, nconf, size(dat,2)); % declare empty variable  
  for n = 1:Nuniques % for each unique type    
    rowidx = find(uniquecolumns(:,n)==1); % row indices for unique type
    colidx = find(j==n); % column indices for unique type    
    if any(uniquecolumns(:,n)) % if vector contains a nonzero number
       beta_temp(n,:,colidx) = regr(rowidx,:)\dat(rowidx,colidx);         % B = X\Y
    end
  end  
  beta = squeeze(nansum(beta_temp,1)); % sum the betas
  clear beta_temp;
  
end

model = regr(:, cfg.reject) * beta(cfg.reject, :);                        % model = confounds * weights = X * X\Y
Yc = dat - model;                                                         % Yclean = Y - X * X\Y

% beta statistics
if isfield(cfg, 'statistics') && strcmp(cfg.statistics, 'yes')
  
  fprintf('performing statistics on the regression weights \n');
  dfe        = nrpt - nconf;                                              % degrees of freedom
  err        = dat - regr * beta;                                         % err = Y - X * B
  mse        = sum((err).^2)/dfe;                                         % mean squared error
  covar      = diag(regr'*regr)';                                         % regressor covariance
  bvar       = repmat(mse',1,size(covar,2))./repmat(covar,size(mse,2),1); % beta variance
  tval       = (beta'./sqrt(bvar))';                                      % betas -> t-values
  prob       = (1-tcdf(tval,dfe))*2;                                      % p-values
  clear err dfe mse bvar;
  % FIXME: drop in replace tcdf from the statfun/private dir
  
end

% reduced models analyses
if isfield(cfg, 'ftest') && ~isempty(cfg.ftest)
  
  dfe        = nrpt - nconf;                                              % degrees of freedom
  err        = dat - regr * beta;                                         % err = Y - X * B
  tmse       = sum((err).^2)/dfe;                                         % mean squared error
  
  for iter = 1:numel(cfg.ftest)
    
    % regressors to test if they explain additional variance
    r          = str2num(cfg.ftest{iter});
    fprintf('F-testing explained additional variance of regressors %s \n', num2str(r));
    % regressors in reduced design (that is the original design)
    ri         = ~ismember(1:size(regr,2),r);
    rX         = regr(:,ri);               % reduced design
    rnr        = size(rX,2);               % number of regressors in reduced design
    % estimate reduced model betas
    rXcov      = pinv(rX'*rX);             % inverse design covariance matrix
    rb         = rXcov*rX'*dat;          	 % beta estimates using pinv
    % calculate mean squared error of reduced model
    rdfe       = size(dat,1) - size(rX,2); % degrees of freedom of the error
    rerr       = dat-rX*rb;                % residual error
    rmse       = sum(rerr'.^2,2)./rdfe;	   % mean squared error
    % F-test
    F(iter,:)          = ((rmse'-tmse)./(nconf-rnr)) ./ (tmse./(dfe-2));
    % Rik Henson defined F-test
    % F = ( ( rerr'*rerr - err'*err ) / ( nconf-rnr ) ) / ( err'*err/ ( nrpt-nconf ) );
    % convert F-value to p-value
    idx_pos    = F(iter,:) >= 0;
    idx_neg    = ~idx_pos;
    p(iter,:)     = nan(1,size(F(iter,:),2));
    p(iter,idx_pos) = (1-fcdf(F(iter,idx_pos),rnr,rdfe));
    p(iter,idx_neg) = fcdf(-F(iter,idx_neg),rnr,rdfe);
    clear rerr rmse
    % FIXME: drop in replace tcdf from the statfun/private dir
    
  end
  
  clear dfe err tmse;
end

% output handling
dataout       = datain;
  
if istimelock
  
  % put the clean data back into place
  dataout.trial = reshape(Yc, [nrpt, nchan, ntime]); clear Yc;
  
  % update descriptives when already present
  if isfield(dataout, 'var') % remove (old) var
    dataout = rmfield(dataout, 'var');
  end
  if isfield(dataout, 'dof') % remove (old) degrees of freedom
    dataout = rmfield(dataout, 'dof');
  end
  if isfield(dataout, 'avg') % remove (old) avg and reaverage
    fprintf('updating descriptives \n');
    dataout = rmfield(dataout, 'avg');
    tempcfg            = [];
    tempcfg.keeptrials = 'yes';
    dataout = ft_timelockanalysis(tempcfg, dataout); % reaveraging
  end
  
  % make a nested timelock structure that contains the model
  if isfield(cfg, 'model') && strcmp(cfg.model, 'yes')
    fprintf('outputting the model which contains the confounds x weights \n');
    dataout.model.trial   = reshape(model, [nrpt, nchan, ntime]); clear model;
    dataout.model.dimord  = dataout.dimord;
    dataout.model.time    = dataout.time;
    dataout.model.label   = dataout.label;
    if isfield(dataout, 'avg')
      % also average the model
      tempcfg            = [];
      tempcfg.keeptrials = 'yes';
      dataout.model      = ft_timelockanalysis(tempcfg, dataout.model);     % reaveraging
    end
  end
  
  % beta statistics
  if isfield(cfg, 'statistics') && strcmp(cfg.statistics, 'yes')
    dataout.stat     = reshape(tval, [nconf, nchan, ntime]);
    dataout.prob     = reshape(prob, [nconf, nchan, ntime]);
    clear tval prob;
  end
  
  % reduced models analyses
  if isfield(cfg, 'ftest') && ~isempty(cfg.ftest)
    dataout.fvar   = reshape(F, [numel(cfg.ftest), nchan, ntime]);
    dataout.pvar   = reshape(p, [numel(cfg.ftest), nchan, ntime]);
    clear F p;
  end
  
  % add the beta weights to the output
  dataout.beta       = reshape(beta, [nconf, nchan, ntime]);
  clear beta dat;
  
elseif isfreq
  
  % put the clean data back into place
  dataout.powspctrm = reshape(Yc, [nrpt, nchan, nfreq, ntime]); clear Yc;
  
  % update descriptives when already present
  if isfield(dataout, 'var') % remove (old) var
    dataout = rmfield(dataout, 'var');
  end
  if isfield(dataout, 'dof') % remove (old) degrees of freedom
    dataout = rmfield(dataout, 'dof');
  end
  if isfield(dataout, 'avg') % remove (old) avg and reaverage
    fprintf('updating descriptives \n');
    dataout = rmfield(dataout, 'avg');
    tempcfg            = [];
    tempcfg.keeptrials = 'yes';
    dataout = ft_freqdescriptives(tempcfg, dataout); % reaveraging
  end
  
  % make a nested freq structure that contains the model
  if isfield(cfg, 'model') && strcmp(cfg.model, 'yes')
    fprintf('outputting the model which contains the confounds x weights \n');
    dataout.model.trial   = reshape(model, [nrpt, nchan, nfreq, ntime]); clear model;
    dataout.model.dimord  = dataout.dimord;
    dataout.model.label   = dataout.label;
    if isfield(dataout, 'time')
      dataout.model.time    = dataout.time;
    end
    if isfield(dataout, 'avg')
      % also average the model
      tempcfg            = [];
      tempcfg.keeptrials = 'yes';
      dataout.model      = ft_freqdescriptives(tempcfg, dataout.model);     % reaveraging
    end
  end
  
  % beta statistics
  if isfield(cfg, 'statistics') && strcmp(cfg.statistics, 'yes')
    dataout.stat     = reshape(tval, [nconf, nchan, nfreq, ntime]);
    dataout.prob     = reshape(prob, [nconf, nchan, nfreq, ntime]);
    clear tval prob;
  end
  
  % reduced models analyses
  if isfield(cfg, 'ftest') && ~isempty(cfg.ftest)
    dataout.fvar   = reshape(F, [numel(cfg.ftest), nchan, nfreq, ntime]);
    dataout.pvar   = reshape(p, [numel(cfg.ftest), nchan, nfreq, ntime]);
    clear F p;
  end
  
  % add the beta weights to the output
  dataout.beta     = reshape(beta, [nconf, nchan, nfreq, ntime]);
  clear beta dat;
  
elseif issource

  % put the clean data back into place
  for i = 1:nrpt
    dataout.trial(1,i).pow = zeros(nvox,1);
    dataout.trial(1,i).pow(dataout.inside) = Yc(i,:);
  end
  clear Yc;
  
  % update descriptives when already present
  if isfield(dataout, 'var') % remove (old) var
    dataout = rmfield(dataout, 'var');
  end
  if isfield(dataout, 'dof') % remove (old) degrees of freedom
    dataout = rmfield(dataout, 'dof');
  end
  if isfield(dataout, 'avg') % remove (old) avg and reaverage
    fprintf('updating descriptives \n');
    dataout = rmfield(dataout, 'avg');
    tempcfg            = [];
    tempcfg.keeptrials = 'yes';
    dataout = ft_sourcedescriptives(tempcfg, dataout); % reaveraging
  end
  
  % make a nested source structure that contains the model
  if isfield(cfg, 'model') && strcmp(cfg.model, 'yes')
    fprintf('outputting the model which contains the confounds x weights \n');
    for i = 1:nrpt
      dataout.model.trial(1,i).pow = zeros(nvox,1);
      dataout.model.trial(1,i).pow(dataout.inside) = model(i,:);
    end
    clear model;
    if isfield(dataout, 'avg')
      % also average the model
      tempcfg            = [];
      tempcfg.keeptrials = 'yes';
      dataout.model      = ft_sourcedescriptives(tempcfg, dataout.model);   % reaveraging
    end
  end
  
  % beta statistics
  if isfield(cfg, 'statistics') && strcmp(cfg.statistics, 'yes')
    dataout.stat                       = zeros(nconf, nvox);
    dataout.stat(:,dataout.inside)     = tval;
    dataout.prob                       = zeros(nconf, nvox);
    dataout.prob(:,dataout.inside)     = prob;
    clear tval prob;
  end
  
  % add the beta weights to the output
  dataout.beta = zeros(nconf, nvox);
  dataout.beta(:,dataout.inside) = beta;
  clear beta dat;
  
end

% discard the gradiometer information because the weightings have been changed
if isfield(dataout, 'grad')
  warning('discarding gradiometer information because the weightings have been changed');
  dataout = rmfield(dataout, 'grad');
end

% discard the electrode information because the weightings have been changed
if isfield(dataout, 'elec')
  warning('discarding electrode information because the weightings have been changed');
  dataout = rmfield(dataout, 'elec');
end

% do the general cleanup and bookkeeping at the end of the function
ft_postamble debug
ft_postamble trackconfig
ft_postamble provenance
ft_postamble previous datain

% rename the output variable to accomodate the savevar postamble
data = dataout;
clear dataout

ft_postamble history data
ft_postamble savevar data
