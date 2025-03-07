function [data] = ft_denoise_synthetic(cfg, data)

% FT_DENOISE_SYNTHETIC computes CTF higher-order synthetic gradients for
% preprocessed data and for the corresponding gradiometer definition.
%
% Use as
%   [data] = ft_denoise_synthetic(cfg, data);
%
% where data should come from FT_PREPROCESSING and the configuration should contain
%   cfg.gradient = 'none', 'G1BR', 'G2BR' or 'G3BR' specifies the gradiometer
%                  type to which the data should be changed
%   cfg.trials   = 'all' or a selection given as a 1xN vector (default = 'all')
%
% To facilitate data-handling and distributed computing you can use
%   cfg.inputfile   =  ...
%   cfg.outputfile  =  ...
% If you specify one of these (or both) the input data will be read from a *.mat
% file on disk and/or the output data will be written to a *.mat file. These mat
% files should contain only a single variable, corresponding with the
% input/output structure.
%
% See also FT_PREPROCESSING, FT_DENOISE_PCA

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
% $Id: ft_denoise_synthetic.m 9521 2014-05-14 09:45:42Z roboos $

revision = '$Id: ft_denoise_synthetic.m 9521 2014-05-14 09:45:42Z roboos $';

% do the general setup of the function
ft_defaults
ft_preamble init
ft_preamble provenance
ft_preamble trackconfig
ft_preamble debug
ft_preamble loadvar data

% the abort variable is set to true or false in ft_preamble_init
if abort
  return
end

% check if the input cfg is valid for this function
cfg = ft_checkconfig(cfg, 'required', {'gradient'});

% set the defaults
if ~isfield(cfg, 'trials'), cfg.trials = 'all'; end

% store the original type of the input data
dtype = ft_datatype(data);

% check if the input data is valid for this function
% this will convert timelocked input data to a raw data representation if needed
data = ft_checkdata(data, 'datatype', 'raw', 'feedback', 'yes', 'hassampleinfo', 'yes');

% check whether it is CTF data
if ~ft_senstype(data, 'ctf')
  error('synthetic gradients can only be computed for CTF data');
end

% check whether there are reference channels in the input data
hasref = ~isempty(ft_channelselection('MEGREF', data.label));
if ~hasref
  error('ft_denoise_synthetic:nohasref', 'synthetic gradients can only be computed when the input data contains reference channels');
end

% select trials of interest
if ~strcmp(cfg.trials, 'all')
  fprintf('selecting %d trials\n', length(cfg.trials));
  data = ft_selectdata(data, 'rpt', cfg.trials);
end

% remember the original channel ordering
labelorg = data.label;

% apply the balancing to the MEG data and to the gradiometer definition
current = data.grad.balance.current;
desired = cfg.gradient;

if ~strcmp(current, 'none')
  % first undo/invert the previously applied balancing
  try
    current_montage = getfield(data.grad.balance, current);
  catch
    error('unknown balancing for input data');
  end
  fprintf('converting from "%s" to "none"\n', current);
  data.grad = ft_apply_montage(data.grad, current_montage, 'keepunused', 'yes', 'inverse', 'yes');
  data      = ft_apply_montage(data     , current_montage, 'keepunused', 'yes', 'inverse', 'yes');
  data.grad.balance.current = 'none';
end % if

if ~strcmp(desired, 'none')
  % then apply the desired balancing
  try
    desired_montage = getfield(data.grad.balance, desired);
  catch
    error('unknown balancing for input data');
  end
  fprintf('converting from "none" to "%s"\n', desired);
  data.grad = ft_apply_montage(data.grad, desired_montage, 'keepunused', 'yes', 'balancename', desired);
  data      = ft_apply_montage(data     , desired_montage, 'keepunused', 'yes', 'balancename', desired);
  %data.grad.balance.current = desired;
end % if

% reorder the channels to stay close to the original ordering
[selorg, selnew] = match_str(labelorg, data.label);
if numel(selnew)==numel(labelorg)
  for i=1:numel(data.trial)
    data.trial{i} = data.trial{i}(selnew,:);
  end
  data.label = data.label(selnew);
else
  warning('channel ordering might have changed');
end

% convert back to input type if necessary
switch dtype
  case 'timelock'
    data = ft_checkdata(data, 'datatype', 'timelock');
  otherwise
    % keep the output as it is
end

% do the general cleanup and bookkeeping at the end of the function
ft_postamble debug
ft_postamble trackconfig
ft_postamble provenance
ft_postamble previous data
ft_postamble history data
ft_postamble savevar data

