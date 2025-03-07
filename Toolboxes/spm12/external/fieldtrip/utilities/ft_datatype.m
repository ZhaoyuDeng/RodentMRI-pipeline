function [type, dimord] = ft_datatype(data, desired)

% FT_DATATYPE determines the type of data represented in a FieldTrip data
% structure and returns a string with raw, freq, timelock source, comp,
% spike, source, volume, dip.
%
% Use as
%   [type, dimord] = ft_datatype(data)
%   [status]       = ft_datatype(data, desired)
%
% See also FT_DATATYPE_COMP FT_DATATYPE_FREQ FT_DATATYPE_MVAR
% FT_DATATYPE_SEGMENTATION FT_DATATYPE_PARCELLATION FT_DATATYPE_SOURCE
% FT_DATATYPE_TIMELOCK FT_DATATYPE_DIP FT_DATATYPE_HEADMODEL
% FT_DATATYPE_RAW FT_DATATYPE_SENS FT_DATATYPE_SPIKE FT_DATATYPE_VOLUME

% Copyright (C) 2008-2012, Robert Oostenveld
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
% $Id: ft_datatype.m 9850 2014-09-27 09:41:31Z roboos $

if nargin<2
  desired = [];
end

% determine the type of input data, this can be raw, freq, timelock, comp, spike, source, volume, dip, segmentation, parcellation
israw          =  isfield(data, 'label') && isfield(data, 'time') && isa(data.time, 'cell') && isfield(data, 'trial') && isa(data.trial, 'cell') && ~isfield(data,'trialtime');
isfreq         = (isfield(data, 'label') || isfield(data, 'labelcmb')) && isfield(data, 'freq') && ~isfield(data,'trialtime') && ~isfield(data,'origtrial'); %&& (isfield(data, 'powspctrm') || isfield(data, 'crsspctrm') || isfield(data, 'cohspctrm') || isfield(data, 'fourierspctrm') || isfield(data, 'powcovspctrm'));
istimelock     =  isfield(data, 'label') && isfield(data, 'time') && ~isfield(data, 'freq') && ~isfield(data,'timestamp') && ~isfield(data,'trialtime') && ~(isfield(data, 'trial') && iscell(data.trial)); %&& ((isfield(data, 'avg') && isnumeric(data.avg)) || (isfield(data, 'trial') && isnumeric(data.trial) || (isfield(data, 'cov') && isnumeric(data.cov))));
iscomp         =  isfield(data, 'label') && isfield(data, 'topo') || isfield(data, 'topolabel');
isvolume       =  isfield(data, 'transform') && isfield(data, 'dim') && ~isfield(data, 'pos');
issource       =  isfield(data, 'pos');
isdip          =  isfield(data, 'dip');
ismvar         =  isfield(data, 'dimord') && ~isempty(strfind(data.dimord, 'lag'));
isfreqmvar     =  isfield(data, 'freq') && isfield(data, 'transfer');
ischan         = check_chan(data);
issegmentation = check_segmentation(data);
isparcellation = check_parcellation(data);

if ~isfreq
  % this applies to a freq structure from 2003 up to early 2006
  isfreq = all(isfield(data, {'foi', 'label', 'dimord'})) && ~isempty(strfind(data.dimord, 'frq'));
end

% check if it is a spike structure
spk_hastimestamp  = isfield(data,'label') && isfield(data, 'timestamp') && isa(data.timestamp, 'cell');
spk_hastrials     = isfield(data,'label') && isfield(data, 'time') && isa(data.time, 'cell') && isfield(data, 'trial') && isa(data.trial, 'cell') && isfield(data, 'trialtime') && isa(data.trialtime, 'numeric');
spk_hasorig       = isfield(data,'origtrial') && isfield(data,'origtime'); % for compatibility
isspike           = isfield(data, 'label') && (spk_hastimestamp || spk_hastrials || spk_hasorig);

% check if it is a sensor array
isgrad = isfield(data, 'label') && isfield(data, 'coilpos') && isfield(data, 'coilori');
iselec = isfield(data, 'label') && isfield(data, 'elecpos');

if isspike
  type = 'spike';
elseif israw && iscomp
  type = 'raw+comp';
elseif istimelock && iscomp
  type = 'timelock+comp';
elseif isfreq && iscomp
    type = 'freq+comp';
elseif israw
  type = 'raw';
elseif iscomp
  type = 'comp';
elseif isfreqmvar
  % freqmvar should conditionally go before freq, otherwise the returned ft_datatype will be freq in the case of frequency mvar data
  type = 'freqmvar';
elseif isfreq
  type = 'freq';
elseif ismvar
  type = 'mvar';
elseif isdip
  % dip should conditionally go before timelock, otherwise the ft_datatype will be timelock
  type = 'dip';
elseif istimelock
  type = 'timelock';
elseif issegmentation
  % a segmentation data structure is a volume data structure, but in general not vice versa
  % segmentation should conditionally go before volume, otherwise the returned ft_datatype will be volume
  type = 'segmentation';
elseif isvolume
  type = 'volume';
elseif isparcellation
  % a parcellation data structure is a source data structure, but in general not vice versa
  % parcellation should conditionally go before source, otherwise the returned ft_datatype will be source
  type = 'parcellation';
elseif issource
  type = 'source';
elseif ischan
  % this results from avgovertime/avgoverfreq after timelockstatistics or freqstatistics
  type = 'chan';
elseif iselec
  type = 'elec';
elseif isgrad
  type = 'grad';
else
  type = 'unknown';
end

if nargin>1
  % return a boolean value
  switch desired
    case 'raw'
      type = any(strcmp(type, {'raw', 'raw+comp'}));
    case 'timelock'
      type = any(strcmp(type, {'timelock', 'timelock+comp'}));
    case 'freq'
      type = any(strcmp(type, {'freq', 'freq+comp'}));
    case 'comp'
      type = any(strcmp(type, {'comp', 'raw+comp', 'timelock+comp', 'freq+comp'}));
    case 'volume'
      type = any(strcmp(type, {'volume', 'segmentation'}));
    case 'source'
      type = any(strcmp(type, {'source', 'parcellation'}));
    case 'sens'
      type = any(strcmp(type, {'elec', 'grad'}));
    otherwise
      type = strcmp(type, desired);
  end % switch
end

if nargout>1
  % FIXME this should be replaced with getdimord in the calling code
  % also return the dimord of the input data
  if isfield(data, 'dimord')
    dimord = data.dimord;
  else
    dimord = 'unknown';
  end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [res] = check_chan(data)

if any(isfield(data, {'time', 'freq', 'pos', 'dim', 'transform'}))
  res = false;
elseif isfield(data, 'dimord') && any(strcmp(data.dimord, {'chan', 'chan_chan'}))
  res = true;
else
  res = false;
  fn = fieldnames(data);
  for i=1:numel(fn)
    if isfield(data, [fn{i} 'dimord']) && any(strcmp(data.([fn{i} 'dimord']), {'chan', 'chan_chan'}))
      res = true;
      break;
    end
  end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [res] = check_segmentation(volume)
res = false;

if ~isfield(volume, 'dim')
  return
end

if isfield(volume, 'pos')
  return
end

if any(isfield(volume, {'seg', 'csf', 'white', 'gray', 'skull', 'scalp', 'brain'}))
  res = true;
  return
end

fn = fieldnames(volume);
isboolean = [];
cnt = 0;
for i=1:length(fn)
  if isfield(volume, [fn{i} 'label'])
    res = true;
    return
  else
    if (islogical(volume.(fn{i})) || isnumeric(volume.(fn{i}))) && isequal(size(volume.(fn{i})),volume.dim)
      cnt = cnt+1;
      if islogical(volume.(fn{i}))
        isboolean(cnt) = true;
      else
        isboolean(cnt) = false;
      end
    end
  end
end
if ~isempty(isboolean)
  res = all(isboolean);
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [res] = check_parcellation(source)
res = false;

if ~isfield(source, 'pos')
  return
end

fn = fieldnames(source);
fb = false(size(fn));
npos = size(source.pos,1);
for i=1:numel(fn)
  % for each of the fields check whether it might be a logical array with the size of the number of sources
  tmp = source.(fn{i});
  fb(i) = numel(tmp)==npos && islogical(tmp);
end
if sum(fb)>1
  % the presence of multiple logical arrays suggests it is a parcellation
  res = true;
end

if res == false      % check if source has more D elements
  check = 0;
  for i = 1: length(fn)
    fname = fn{i};
    switch fname
      case 'tri'
        npos = size(source.tri,1);
        check = 1;
      case 'hex'
        npos = size(source.hex,1);
        check = 1;
      case 'tet'
        npos = size(source.tet,1);
        check = 1;
    end
  end
  if check == 1   % check if elements are labelled
    for i=1:numel(fn)
      tmp = source.(fn{i});
      fb(i) = numel(tmp)==npos && islogical(tmp);
    end
    if sum(fb)>1
      res = true;
    end
  end
end

fn = fieldnames(source);
for i=1:length(fn)
  if isfield(source, [fn{i} 'label'])
    res = true;
    return
  end
end
