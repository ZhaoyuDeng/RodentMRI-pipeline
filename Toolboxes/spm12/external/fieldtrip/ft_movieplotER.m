function [cfg] = ft_movieplotER(cfg, data)

% FT_MOVIEPLOTER makes a movie of the topographic distribution of the
% time-locked average.
%
% Use as
%   ft_movieplotER(cfg, timelock)
% where the input data is from FT_TIMELOCKANALYSIS and the configuration
% can contain
%   cfg.parameter    = string, parameter that is color coded (default = 'avg')
%   cfg.xlim         = 'maxmin' or [xmin xmax] (default = 'maxmin')
%   cfg.zlim         = plotting limits for color dimension, 'maxmin',
%                          'maxabs', 'zeromax', 'minzero', or [zmin zmax] (default = 'maxmin')
%   cfg.samperframe  = number, samples per fram (default = 1)
%   cfg.framespersec = number, frames per second (default = 5)
%   cfg.framesfile   = [], no file saved, or 'string', filename of saved frames.mat (default = []);
%   cfg.layout       = specification of the layout, see below
%
% The layout defines how the channels are arranged. You can specify the
% layout in a variety of ways:
%  - you can provide a pre-computed layout structure (see prepare_layout)
%  - you can give the name of an ascii layout file with extension *.lay
%  - you can give the name of an electrode file
%  - you can give an electrode definition, i.e. "elec" structure
%  - you can give a gradiometer definition, i.e. "grad" structure
% If you do not specify any of these and the data structure contains an
% electrode or gradiometer structure, that will be used for creating a
% layout. If you want to have more fine-grained control over the layout
% of the subplots, you should create your own layout file.
%
% To facilitate data-handling and distributed computing you can use
%   cfg.inputfile   =  ...
% If you specify this option the input data will be read from a *.mat
% file on disk. This mat files should contain only a single variable named 'data',
% corresponding to the input structure.

% Copyright (C) 2009, Ingrid Nieuwenhuis
% Copyright (C) 2011, Jan-Mathijs Schoffelen, Robert Oostenveld, Cristiano Micheli
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
% $Id: ft_movieplotER.m 9748 2014-07-21 12:38:01Z jansch $

revision = '$Id: ft_movieplotER.m 9748 2014-07-21 12:38:01Z jansch $';

% do the general setup of the function
ft_defaults
ft_preamble init
ft_preamble provenance

% the abort variable is set to true or false in ft_preamble_init
if abort
  return
end

% check if the input data is valid for this function
data = ft_checkdata(data, 'datatype', 'timelock');

% set the defaults
cfg.parameter   = ft_getopt(cfg, 'parameter', 'avg');
cfg.interactive = ft_getopt(cfg, 'interactive', 'no');

cfg = ft_movieplotTFR(cfg, data);

% do the general cleanup and bookkeeping at the end of the function
% this will replace the ft_movieplotTFR callinfo with that of ft_movieplotER
ft_postamble provenance
ft_postamble previous data

