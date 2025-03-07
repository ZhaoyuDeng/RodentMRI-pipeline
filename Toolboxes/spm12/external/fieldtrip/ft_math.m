function data = ft_math(cfg, varargin)

% FT_MATH performs mathematical operations on FieldTrip data structures,
% such as addition, subtraction, division, etc.
%
% Use as
%   data = ft_examplefunction(cfg, data1, data2, ...)
% with one or multiple FieldTrip data structures as input and where cfg is a
% configuration structure that should contain
%
%  cfg.operation  = string, can be 'add', 'subtract', 'divide', 'multiply', 'log10'
%                   or a functional specification of the operation (see below)
%  cfg.parameter  = string, field from the input data on which the operation is
%                   performed, e.g. 'pow' or 'avg'
%
% Optionally, if you specify only a single input data structure and the operation
% 'add', 'subtract', 'divide' or 'multiply', the configuration should also contain
%   cfg.scalar    = scalar value to be used in the operation
%
% The operation 'add' is implemented as follows
%   y = x1 + x2 + ....
% if you specify multiple input arguments, or as
%   y = x1 + s
% if you specify one input argument and a scalar value.
%
% The operation 'subtract' is implemented as follows
%   y = x1 - x2 - ....
% if you specify multiple input arguments, or as
%   y = x1 - s
% if you specify one input argument and a scalar value.
%
% The operation 'divide' is implemented as follows
%   y = x1 ./ x2
% if you specify two input arguments, or as
%   y = x1 / s
% if you specify one input argument and a scalar value.
%
% The operation 'multiply' is implemented as follows
%   y = x1 .* x2
% if you specify two input arguments, or as
%   y = x1 * s
% if you specify one input argument and a scalar value.
%
% It is also possible to specify your own operation as a string, like this
%   cfg.operation = '(x1-x2)/(x1+x2)'
% or using 's' for the scalar value like this
%   cfg.operation = '(x1-x2)^s'
%
% To facilitate data-handling and distributed computing you can use
%   cfg.inputfile   =  ...
%   cfg.outputfile  =  ...
% If you specify one of these (or both) the input data will be read from a *.mat
% file on disk and/or the output data will be written to a *.mat file. These mat
% files should contain only a single variable, corresponding with the
% input/output structure.
%
% See also FT_DATATYPE

% Undocumented options:
%   cfg.matrix = rather than using a scalar, a matrix can be specified. In
%                this case, the dimensionality of cfg.matrix should be equal 
%                to the dimensionality of data.(cfg.parameter). If used in
%                combination with cfg.operation, the operation should
%                involve element-wise combination of the data and the
%                matrix.

% Copyright (C) 2012-2014, Robert Oostenveld
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
% $Id: ft_math.m 9868 2014-10-01 07:53:22Z jansch $

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% the initial part deals with parsing the input options and data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

revision = '$Id: ft_math.m 9868 2014-10-01 07:53:22Z jansch $';

ft_defaults                   % this ensures that the path is correct and that the ft_defaults global variable is available
ft_preamble init              % this will show the function help if nargin==0 and return an error
ft_preamble provenance        % this records the time and memory usage at teh beginning of the function
ft_preamble trackconfig       % this converts the cfg structure in a config object, which tracks the cfg options that are being used
ft_preamble debug
ft_preamble loadvar varargin  % this reads the input data in case the user specified the cfg.inputfile option

% the abort variable is set to true or false in ft_preamble_init
if abort
  return
end

type = ft_datatype(varargin{1});
for i=1:length(varargin)
  % check if the input data is valid for this function, that all data types are equal and update old data structures
  varargin{i} = ft_checkdata(varargin{i}, 'datatype', type);
end

% ensure that the required options are present
cfg = ft_checkconfig(cfg, 'required', {'operation', 'parameter'});
cfg = ft_checkconfig(cfg, 'renamed', {'value', 'scalar'});

% this function only works for the upcoming (not yet standard) source representation without sub-structures
if ft_datatype(varargin{1}, 'source')
  % update the old-style beamformer source reconstruction
  for i=1:length(varargin)
    varargin{i} = ft_datatype_source(varargin{i}, 'version', 'upcoming');
  end
  if isfield(cfg, 'parameter') && length(cfg.parameter)>4 && strcmp(cfg.parameter(1:4), 'avg.')
    cfg.parameter = cfg.parameter(5:end); % remove the 'avg.' part
  end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% the actual computation is done in the middle part
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~issubfield(varargin{1}, cfg.parameter)
  error('the requested parameter is not present in the data');
end

% ensure that the data in all inputs has the same channels, time-axis, etc.
tmpcfg = [];
tmpcfg.parameter = cfg.parameter;
[varargin{:}] = ft_selectdata(tmpcfg, varargin{:});
% restore the provenance information
[cfg, varargin{:}] = rollback_provenance(cfg, varargin{:});

cfg.parameter = tmpcfg.parameter;

dimord = getdimord(varargin{1}, cfg.parameter);
dimtok = tokenize(dimord, '_');

% this determines which descriptive fields will get copied over
haschan = any(strcmp(dimtok, 'chan'));
hasfreq = any(strcmp(dimtok, 'freq'));
hastime = any(strcmp(dimtok, 'time'));
haspos  = any(strcmp(dimtok, 'pos'));

% construct the output data structure
data = [];
if haschan
  data.label = varargin{1}.label;
end
if hasfreq
  data.freq = varargin{1}.freq;
end
if hastime
  data.time = varargin{1}.time;
end
if haspos
  if isfield(varargin{1}, 'pos')
    data.pos = varargin{1}.pos;
  end
  if isfield(varargin{1}, 'dim')
    data.dim = varargin{1}.dim;
  end
  if isfield(varargin{1}, 'transform')
    data.transform = varargin{1}.transform;
  end
end

% use an anonymous function
assign = @(var, val) assignin('caller', var, val);

fprintf('selecting %s from the first input argument\n', cfg.parameter);
% create the local variables x1, x2, ...
for i=1:length(varargin)
  assign(sprintf('x%i', i), getsubfield(varargin{i}, cfg.parameter));
end

% create the local variables s and m
s = ft_getopt(cfg, 'scalar');
m = ft_getopt(cfg, 'matrix');

% check the dimensionality of m against the input data
if ~isempty(m),
  for i=1:length(varargin)
    ok = isequal(size(getsubfield(varargin{i}, cfg.parameter)),size(m));
    if ~ok, break; end
  end
  if ~ok,
    error('the dimensions of cfg.matrix do not allow for element-wise operations');
  end
end

% only one of these can be defined at the moment (i.e. not allowing for
% operations such as (x1+m)^s for now
if ~isempty(m) && ~isempty(s),
  error('you can either specify a cfg.matrix or a cfg.scalar, not both');
end

% touch it to keep track of it in the output cfg
if ~isempty(s), cfg.scalar; end
if ~isempty(m), cfg.matrix; end

% replace s with m, so that the code below is more transparent
if ~isempty(m),
  s = m; clear m;
end

if length(varargin)==1
  switch cfg.operation
    case 'add'
      if isscalar(s),
        fprintf('adding %f to the %s\n', s, cfg.parameter);
      else
        fprintf('adding the contents of cfg.matrix to the %s\n', cfg.parameter);
      end
      if iscell(x1)
        y = cellplus(x1, s);
      else
        y = x1 + s;
      end
      
    case 'subtract'
      if isscalar(s),
        fprintf('subtracting %f from the %s\n', s, cfg.parameter);
      else
        fprintf('subtracting the contents of cfg.matrix from the %s\n', cfg.parameter);
      end
      if iscell(x1)
        y = cellminus(x1, s);
      else
        y = x1 - s;
      end
      
    case 'multiply'
      if isscalar(s),
        fprintf('multiplying %s with %f\n', cfg.parameter, s);
      else
        fprintf('multiplying %s with the content of cfg.matrix\n', cfg.parameter);
      end
      fprintf('multiplying %s with %f\n', cfg.parameter, s);
      if iscell(x1)
        y = celltimes(x1, s);
      else
        y = x1 .* s;
      end
      
    case 'divide'
      if isscalar(s),
        fprintf('dividing %s by %f\n', cfg.parameter, s);
      else
        fprintf('dividing %s by the content of cfg.matrix\n', cfg.parameter);
      end
      if iscell(x1)
        y = cellrdivide(x1, s);
      else
        y = x1 ./ s;
      end
      
    case 'log10'
      fprintf('taking the log10 of %s\n', cfg.parameter);
      if iscell(x1)
        y = celllog10(x1);
      else
        y = log10(x1);
      end
      
    otherwise
      % assume that the operation is descibed as a string, e.g. x1^s
      % where x1 is the first argument and s is obtained from cfg.scalar
      
      arginstr = sprintf('x%i,', 1:length(varargin));
      arginstr = arginstr(1:end-1); % remove the trailing ','
      eval(sprintf('operation = @(%s) %s;', arginstr, cfg.operation));
      
      if ~iscell(varargin{1}.(cfg.parameter))
        % gather x1, x2, ... into a cell-array
        arginval = eval(sprintf('{%s}', arginstr));
        eval(sprintf('operation = @(%s) %s;', arginstr, cfg.operation));
        if isscalar(s)
          y = arrayfun(operation, arginval{:});
        elseif size(s)==size(arginval{1})
          y = feval(operation, arginval{:});
        end
      else
        y = cell(size(x1));
        % do the same thing, but now for each element of the cell array
        for i=1:numel(y)
          for j=1:length(varargin)
            % rather than working with x1 and x2, we need to work on its elements
            % xx1 is one element of the x1 cell-array
            assign(sprintf('xx%d', j), eval(sprintf('x%d{%d}', j, i)))
          end
          
          % gather xx1, xx2, ... into a cell-array
          arginstr = sprintf('xx%i,', 1:length(varargin));
          arginstr = arginstr(1:end-1); % remove the trailing ','
          arginval = eval(sprintf('{%s}', arginstr));
          if isscalar(s)
            y{i} = arrayfun(operation, arginval{:});
          else
            y{i} = feval(operation, arginval{:});
          end
        end % for each element
      end % iscell or not
      
  end % switch
  
  
else
  
  switch cfg.operation
    case 'add'
      for i=2:length(varargin)
        fprintf('adding the %s input argument\n', nth(i));
        if iscell(x1)
          y = cellplus(x1, varargin{i}.(cfg.parameter));
        else
          y = x1 + varargin{i}.(cfg.parameter);
        end
      end
      
    case 'multiply'
      for i=2:length(varargin)
        fprintf('multiplying with the %s input argument\n', nth(i));
        if iscell(x1)
          y = celltimes(x1, varargin{i}.(cfg.parameter));
        else
          y = x1 .* varargin{i}.(cfg.parameter);
        end
      end
      
    case 'subtract'
      if length(varargin)>2
        error('the operation "%s" requires exactly 2 input arguments', cfg.operation);
      end
      fprintf('subtracting the 2nd input argument from the 1st\n');
      if iscell(x1)
        y = cellminus(x1, varargin{2}.(cfg.parameter));
      else
        y = x1 - varargin{2}.(cfg.parameter);
      end
      
    case 'divide'
      if length(varargin)>2
        error('the operation "%s" requires exactly 2 input arguments', cfg.operation);
      end
      fprintf('dividing the 1st input argument by the 2nd\n');
      if iscell(x1)
        y = cellrdivide(x1, varargin{2}.(cfg.parameter));
      else
        y = x1 ./ varargin{2}.(cfg.parameter);
      end
            
    case 'log10'
      if length(varargin)>2
        error('the operation "%s" requires exactly 2 input arguments', cfg.operation);
      end
      fprintf('taking the log difference between the 2nd input argument and the 1st\n');
      y = log10(x1 ./ varargin{2}.(cfg.parameter));
      
    otherwise
      % assume that the operation is descibed as a string, e.g. (x1-x2)/(x1+x2)
      
      % ensure that all input arguments are being used
      for i=1:length(varargin)
        assert(~isempty(regexp(cfg.operation, sprintf('x%i', i), 'once')), 'not all input arguments are assigned in the operation')
      end
      
      arginstr = sprintf('x%i,', 1:length(varargin));
      arginstr = arginstr(1:end-1); % remove the trailing ','
      eval(sprintf('operation = @(%s) %s;', arginstr, cfg.operation));
      
      if ~iscell(varargin{1}.(cfg.parameter))
        % gather x1, x2, ... into a cell-array
        arginval = eval(sprintf('{%s}', arginstr));
        eval(sprintf('operation = @(%s) %s;', arginstr, cfg.operation));
        if isscalar(s)
          y = arrayfun(operation, arginval{:});
        else
          y = feval(operation, arginval{:});
        end
      else
        y = cell(size(x1));
        % do the same thing, but now for each element of the cell array
        for i=1:numel(y)
          for j=1:length(varargin)
            % rather than working with x1 and x2, we need to work on its elements
            % xx1 is one element of the x1 cell-array
            assign(sprintf('xx%d', j), eval(sprintf('x%d{%d}', j, i)))
          end
          
          % gather xx1, xx2, ... into a cell-array
          arginstr = sprintf('xx%i,', 1:length(varargin));
          arginstr = arginstr(1:end-1); % remove the trailing ','
          arginval = eval(sprintf('{%s}', arginstr));
          if isscalar(s)
            y{i} = arrayfun(operation, arginval{:});
          else
            y{i} = feval(operation, arginval{:});
          end
        end % for each element
      end % iscell or not
      
  end % switch
end % one or multiple input data structures

% store the result of the operation in the output structure
data = setsubfield(data, cfg.parameter, y);
data.dimord = dimord;

% certain fields should remain in the output, but only if they are identical in all inputs
keepfield = {'grad', 'elec'};
for j=1:numel(keepfield)
  if isfield(varargin{1}, keepfield{j})
    tmp  = varargin{i}.(keepfield{j});
    keep = true;
  else
    keep = false;
  end
  for i=1:numel(varargin)
    if ~isfield(varargin{i}, keepfield{j}) || ~isequal(varargin{i}.(keepfield{j}), tmp)
      keep = false;
      break
    end
  end
  if keep
    data.(keepfield{j}) = tmp;
  end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% deal with the output
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

ft_postamble debug
ft_postamble trackconfig        % this converts the config object back into a struct and can report on the unused fields
ft_postamble provenance         % this records the time and memory at the end of the function, prints them on screen and adds this information together with the function name and matlab version etc. to the output cfg
ft_postamble previous varargin  % this copies the datain.cfg structure into the cfg.previous field. You can also use it for multiple inputs, or for "varargin"
ft_postamble history data       % this adds the local cfg structure to the output data structure, i.e. dataout.cfg = cfg
ft_postamble savevar data       % this saves the output data structure to disk in case the user specified the cfg.outputfile option

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function s = nth(n)
if rem(n,10)==1 && rem(n,100)~=11
  s = sprintf('%dst', n);
elseif rem(n,10)==2 && rem(n,100)~=12
  s = sprintf('%dnd', n);
elseif rem(n,10)==3 && rem(n,100)~=13
  s = sprintf('%drd', n);
else
  s = sprintf('%dth', n);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTIONS for doing math on each element of a cell-array
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function z = cellplus(x, y)
if ~iscell(y)
  y = repmat({y}, size(x));
end
z = cellfun(@plus, x, y, 'UniformOutput', false);

function z = cellminus(x, y)
if ~iscell(y)
  y = repmat({y}, size(x));
end
z = cellfun(@minus, x, y, 'UniformOutput', false);

function z = celltimes(x, y)
if ~iscell(y)
  y = repmat({y}, size(x));
end
z = cellfun(@times, x, y, 'UniformOutput', false);

function z = cellrdivide(x, y)
if ~iscell(y)
  y = repmat({y}, size(x));
end
z = cellfun(@rdivide, x, y, 'UniformOutput', false);

function z = celllog10(x)
z = cellfun(@log10, x, 'UniformOutput', false);
