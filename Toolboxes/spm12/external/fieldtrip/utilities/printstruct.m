function str = printstruct(name, val)

% PRINTSTRUCT converts a MATLAB structure into a multi-line string that can be
% interpreted by MATLAB, resulting in the original structure.
%
% Use as
%   str = printstruct(val)
% or
%   str = printstruct(name, val)
% where "val" is any MATLAB variable, e.g. a scalar, vector, matrix, structure, or
% cell-array. If you pass the name of the variable, the output is a piece of MATLAB code
% that you can execute, i.e. an ASCII serialized representation of the variable.
%
% Example
%   a.field1 = 1;
%   a.field2 = 2;
%   s = printstruct(a)
%
%   b = rand(3);
%   s = printstruct(b)
%
%   s = printstruct('c', randn(10)>0.5)

% Copyright (C) 2006-2013, Robert Oostenveld
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
% $Id: printstruct.m 9374 2014-04-07 12:45:37Z roboos $

if nargin==1
  val  = name;
  name = inputname(1);
end

if isa(val, 'config')
  % this is fieldtrip specific: the @config object resembles a structure but tracks the
  % access to each field.  In this case it is to be treated as a normal structure.
  val = struct(val);
end

str = '';
if isstruct(val)
  if numel(val)>1
    str = cell(size(val));
    for i=1:numel(val)
      str{i} = printstruct(sprintf('%s(%d)', name, i), val(i));
    end
    str = cat(2, str{:});
    return
  else
    % print it as a named structure
    fn = fieldnames(val);
    for i=1:length(fn)
      if numel(val)==0
        warning('not displaying empty structure')
      else
        fv = val.(fn{i});
        switch class(fv)
          case 'char'
            % line = sprintf('%s = ''%s'';\n', fn{i}, fv);
            % line = [name '.' line];
            line = printstr([name '.' fn{i}], fv);
            str  = [str line];
          case {'single' 'double' 'int8' 'int16' 'int32' 'int64' 'uint8' 'uint16' 'uint32' 'uint64' 'logical'}
            line = printmat([name '.' fn{i}], fv);
            str  = [str line];
          case 'cell'
            line = printcell([name '.' fn{i}], fv);
            str  = [str line];
          case 'struct'
            line = printstruct([name '.' fn{i}], fv);
            str  = [str line];
          case 'function_handle'
            printstr([name '.' fn{i}], func2str(fv));
            str  = [str line];
          otherwise
            error('unsupported');
        end
      end
    end
  end
elseif ~isstruct(val)
  % print it as a named variable
  switch class(val)
    case 'char'
      str = printstr(name, val);
    case {'single' 'double' 'int8' 'int16' 'int32' 'int64' 'uint8' 'uint16' 'uint32' 'uint64' 'logical'}
      str = printmat(name, val);
    case 'cell'
      str = printcell(name, val);
    otherwise
      error('unsupported');
  end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function str = printcell(name, val)
siz = size(val);
if isempty(val)
  str = sprintf('%s = {};\n', name);
  return;
end
typ = cellfun(@class, val(:), 'UniformOutput', false);
if all(size(val)==1)
  str = sprintf('%s = { %s };\n', name, printval(val{1}));
else
  str = sprintf('%s = {\n', name);
  for i=1:siz(1)
    dum = '';
    for j=1:(siz(2)-1)
      dum = [dum ' ' printval(val{i,j}) ',']; % add the element with a comma
    end
    dum = [dum ' ' printval(val{i,siz(2)})]; % add the last one without comma
    str = sprintf('%s%s\n', str, dum);
  end
  str = sprintf('%s};\n', str);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function str = printmat(name, val)
siz = size(val);
if prod(siz)==0
  str = sprintf('%s = [];\n', name);
elseif prod(siz)==1
  str = sprintf('%s = %s;\n', name, printval(val));
elseif numel(siz)==2 && siz(1)==1
    str = '';
    for col=1:siz(2)
      str = sprintf('%s %s', str, printval(val(1,col)));
    end
   str = sprintf('%s = [%s ];\n', name, str);
elseif numel(siz)==2
    str = sprintf('%s = [\n', name);
  for row=1:siz(1)
    for col=1:siz(2)
      str = sprintf('%s %s', str, printval(val(row,col)));
    end
    str = sprintf('%s\n', str);
  end
  str = sprintf('%s];\n', str);
else
  str = sprintf('%s = %s;\n', name, printval(val));
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function str = printstr(name, val)
siz = size(val);
if siz(1)>1
  str = sprintf('%s = \n', name);
  for i=1:siz(1)
    str = [str sprintf('  %s\n', printval(val(i,:)))];
  end
elseif siz(1)==1
  str = sprintf('%s = %s;\n', name, printval(val));
else
  str = sprintf('%s = '''';\n', name);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function str = printbool(val)
% val is a 1xN vector with booleans
dum = {'false ', ' true '}; % note the spaces at the end
str = cat(2, dum{val+1});
str = str(1:end-1); % remove the last space

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function str = printval(val)
siz = size(val);
switch class(val)
  case 'char'
    str = sprintf('''%s''', val);
    
  case 'logical'
    if all(siz==0)
      str = '[]';
    elseif all(siz==1)
      str = sprintf('%s', printbool(val));
    elseif length(siz)==2
      str = [];
      for i=1:siz(1);
        str = [ str sprintf('%s ', printbool(val(i,:))) '; ' ];
      end
      str = sprintf('[ %s ]', str(1:end-3));
    else
      warning('multidimensional arrays are not supported');
      str = '''FIXME: printing multidimensional logical arrays is not supported''';
    end
    
  case {'single' 'double'}
    if all(siz==0)
      str = '[]';
    elseif all(siz==1)
      if isinteger(val)
        str = sprintf('%d', val);
      else
        str = sprintf('%g', val);
      end
    elseif length(siz)==2
      str = [];
      for i=1:siz(1);
        if all(isinteger(val(i,:)))
          str = [ str sprintf('%d ', val(i,:)) '; ' ];
        else
          str = [ str sprintf('%g ', val(i,:)) '; ' ];
        end
      end
      str = sprintf('[ %s ]', str(1:end-3));
    else
      warning('multidimensional arrays are not supported');
      str = '''FIXME: printing multidimensional single and double arrays is supported''';
    end
    
  case {'int8' 'int16' 'int32' 'int64' 'uint8' 'uint16' 'uint32' 'uint64'}
    % this is the same as for double, except for the %d instead of %g
    if all(siz==1)
      str = sprintf('%d', val);
    elseif length(siz)==2
      str = [];
      for i=1:siz(1);
        str = [ str sprintf('%d ', val(i,:)) '; ' ];
      end
      str = sprintf('[ %s ]', str(1:end-3));
    else
      warning('multidimensional arrays are not supported');
      str = '''FIXME: printing multidimensional int/uint arrays is not supported''';
    end
    
  case 'function_handle'
    str = sprintf('@%s', func2str(val));
    
  case 'struct'
    warning('cannot print structure at this level');
    str = '''FIXME: printing structures at this level is not supported''';
    
  otherwise
    warning('cannot print unknown object at this level');
    str = '''FIXME: printing unknown objects is not supported''';
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% helper function to determine whether a floating point value contains an integer number
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function y = isinteger(x)
y = (x==round(x));
