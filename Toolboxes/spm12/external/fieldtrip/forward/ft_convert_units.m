function [obj] = ft_convert_units(obj, target, varargin)

% FT_CONVERT_UNITS changes the geometrical dimension to the specified SI unit.
% The units of the input object is determined from the structure field
% object.unit, or is estimated based on the spatial extend of the structure,
% e.g. a volume conduction model of the head should be approximately 20 cm large.
%
% Use as
%   [object] = ft_convert_units(object, target)
%
% The following geometrical objects are supported as inputs
%   electrode or gradiometer array, see FT_DATATYPE_SENS
%   volume conductor, see FT_DATATYPE_HEADMODEL
%   anatomical mri, see FT_DATATYPE_VOLUME
%   segmented mri, see FT_DATATYPE_SEGMENTATION
%   dipole grid definition, see FT_DATATYPE_SOURCE
%
% Possible target units are 'm', 'dm', 'cm ' or 'mm'. If no target units
% are specified, this function will only determine the native geometrical
% units of the object.
%
% See FT_ESTIMATE_UNITS, FT_READ_VOL, FT_READ_SENS

% Copyright (C) 2005-2013, Robert Oostenveld
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
% $Id: ft_convert_units.m 9013 2013-12-11 09:02:59Z eelspa $

% This function consists of three parts:
%   1) determine the input units
%   2) determine the requested scaling factor to obtain the output units
%   3) try to apply the scaling to the known geometrical elements in the input object

feedback = ft_getopt(varargin, 'feedback', false);

if isstruct(obj) && numel(obj)>1
  % deal with a structure array
  for i=1:numel(obj)
    if nargin>1
      tmp(i) = ft_convert_units(obj(i), target, varargin{:});
    else
      tmp(i) = ft_convert_units(obj(i));
    end
  end
  obj = tmp;
  return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% determine the unit-of-dimension of the input object
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if isfield(obj, 'unit') && ~isempty(obj.unit)
  % use the units specified in the object
  unit = obj.unit;
  
elseif isfield(obj, 'bnd') && isfield(obj.bnd, 'unit')
  
  unit = unique({obj.bnd.unit});
  if ~all(strcmp(unit, unit{1}))
    error('inconsistent units in the individual boundaries');
  else
    unit = unit{1};
  end
  
  % keep one representation of the units rather than keeping it with each boundary
  % the units will be reassigned further down
  obj.bnd = rmfield(obj.bnd, 'unit');
  
else
  % try to determine the units by looking at the size of the object
  if isfield(obj, 'chanpos') && ~isempty(obj.chanpos)
    siz = norm(idrange(obj.chanpos));
    unit = ft_estimate_units(siz);
    
  elseif isfield(obj, 'elecpos') && ~isempty(obj.elecpos)
    siz = norm(idrange(obj.elecpos));
    unit = ft_estimate_units(siz);
    
  elseif isfield(obj, 'coilpos') && ~isempty(obj.coilpos)
    siz = norm(idrange(obj.coilpos));
    unit = ft_estimate_units(siz);
    
  elseif isfield(obj, 'pnt') && ~isempty(obj.pnt)
    siz = norm(idrange(obj.pnt));
    unit = ft_estimate_units(siz);
    
  elseif isfield(obj, 'pos') && ~isempty(obj.pos)
    siz = norm(idrange(obj.pos));
    unit = ft_estimate_units(siz);
    
  elseif isfield(obj, 'transform') && ~isempty(obj.transform)
    % construct the corner points of the volume in voxel and in head coordinates
    [pos_voxel, pos_head] = cornerpoints(obj.dim, obj.transform);
    siz = norm(idrange(pos_head));
    unit = ft_estimate_units(siz);
    
  elseif isfield(obj, 'fid') && isfield(obj.fid, 'pnt') && ~isempty(obj.fid.pnt)
    siz = norm(idrange(obj.fid.pnt));
    unit = ft_estimate_units(siz);
    
  elseif ft_voltype(obj, 'infinite')
    % this is an infinite medium volume conductor, which does not care about units
    unit = 'm';
    
  elseif ft_voltype(obj,'singlesphere')
    siz = obj.r;
    unit = ft_estimate_units(siz);
    
  elseif ft_voltype(obj,'localspheres')
    siz = median(obj.r);
    unit = ft_estimate_units(siz);
    
  elseif ft_voltype(obj,'concentricspheres')
    siz = max(obj.r);
    unit = ft_estimate_units(siz);
    
  elseif isfield(obj, 'bnd') && isstruct(obj.bnd) && isfield(obj.bnd(1), 'pnt') && ~isempty(obj.bnd(1).pnt)
    siz = norm(idrange(obj.bnd(1).pnt));
    unit = ft_estimate_units(siz);
    
  elseif isfield(obj, 'nas') && isfield(obj, 'lpa') && isfield(obj, 'rpa')
    pnt = [obj.nas; obj.lpa; obj.rpa];
    siz = norm(idrange(pnt));
    unit = ft_estimate_units(siz);
    
  else
    error('cannot determine geometrical units');
    
  end % recognized type of volume conduction model or sensor array
end % determine input units

if nargin<2 || isempty(target)
  % just remember the units in the output and return
  obj.unit = unit;
  return
elseif strcmp(unit, target)
  % no conversion is needed
  obj.unit = unit;
  return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% compute the scaling factor from the input units to the desired ones
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
scale = scalingfactor(unit, target);

if istrue(feedback)
  % give some information about the conversion
  fprintf('converting units from ''%s'' to ''%s''\n', unit, target)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% apply the scaling factor
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% volume conductor model
if isfield(obj, 'r'), obj.r = scale * obj.r; end
if isfield(obj, 'o'), obj.o = scale * obj.o; end
if isfield(obj, 'bnd'),
  for i=1:length(obj.bnd)
    obj.bnd(i).pnt = scale * obj.bnd(i).pnt;
  end
end

% gradiometer array
if isfield(obj, 'pnt1'), obj.pnt1 = scale * obj.pnt1; end
if isfield(obj, 'pnt2'), obj.pnt2 = scale * obj.pnt2; end
if isfield(obj, 'prj'),  obj.prj  = scale * obj.prj;  end

% gradiometer array, electrode array, head shape or dipole grid
if isfield(obj, 'pnt'),        obj.pnt     = scale * obj.pnt; end
if isfield(obj, 'chanpos'),    obj.chanpos = scale * obj.chanpos; end
if isfield(obj, 'chanposorg'), obj.chanposorg = scale * obj.chanposorg; end
if isfield(obj, 'coilpos'),    obj.coilpos = scale * obj.coilpos; end
if isfield(obj, 'elecpos'),    obj.elecpos = scale * obj.elecpos; end

% gradiometer array that combines multiple coils in one channel
if isfield(obj, 'tra') && isfield(obj, 'chanunit')
  % find the gradiometer channels that are expressed as unit of field strength divided by unit of distance, e.g. T/cm
  for i=1:length(obj.chanunit)
    tok = tokenize(obj.chanunit{i}, '/');
    if ~isempty(regexp(obj.chanunit{i}, 'm$', 'once'))
      % assume that it is T/m or so
      obj.tra(i,:)    = obj.tra(i,:) / scale;
      obj.chanunit{i} = [tok{1} '/' target];
    elseif ~isempty(regexp(obj.chanunit{i}, '[T|V]$', 'once'))
      % assume that it is T or V, don't do anything
    elseif strcmp(obj.chanunit{i}, 'unknown')
      % assume that it is T or V, don't do anything
    else
      error('unexpected units %s', obj.chanunit{i});
    end
  end % for
end % if

% fiducials
if isfield(obj, 'fid') && isfield(obj.fid, 'pnt'), obj.fid.pnt = scale * obj.fid.pnt; end

% dipole grid
if isfield(obj, 'pos'), obj.pos = scale * obj.pos; end

% anatomical MRI or functional volume
if isfield(obj, 'transform'),
  H = diag([scale scale scale 1]);
  obj.transform = H * obj.transform;
end

if isfield(obj, 'transformorig'),
  H = diag([scale scale scale 1]);
  obj.transformorig = H * obj.transformorig;
end

% remember the unit
obj.unit = target;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% IDRANGE interdecile range for more robust range estimation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function r = idrange(x)
keeprow=true(size(x,1),1);
for l=1:size(x,2)
  keeprow = keeprow & isfinite(x(:,l));
end
sx = sort(x(keeprow,:), 1);
ii = round(interp1([0, 1], [1, size(x(keeprow,:), 1)], [.1, .9]));  % indices for 10 & 90 percentile
r = diff(sx(ii, :));
