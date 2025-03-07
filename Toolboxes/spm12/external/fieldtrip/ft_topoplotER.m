function [cfg] = ft_topoplotER(cfg, varargin)

% FT_TOPOPLOTER plots the topographic distribution over the head
% of a 2-dimensional data representations such as the event-related
% fields or potentials or the power- or coherence spectrum.
%
% Use as
%   ft_topoplotER(cfg, timelock)
% or
%   ft_topoplotER(cfg, freq)
%
% The data can be an erp/erf produced by FT_TIMELOCKANALYSIS, a powerspectrum
% (without time dimension) produced by FT_FREQANALYSIS or a connectivityspectrum
% produced by FT_CONNECTIVITYANALYSIS.  Also, the output to FT_FREQSTATISTICS
% and FT_TIMELOCKSTATISTICS can be visualised.
%
% The configuration can have the following parameters:
%   cfg.parameter          = field that contains the data to be plotted as color
%                           'avg', 'powspctrm' or 'cohspctrm' (default depends on data.dimord)
%   cfg.maskparameter      = field in the data to be used for masking of
%                            data. Values between 0 and 1, 0 = transparent
%   cfg.xlim               = selection boundaries over first dimension in data (e.g., time)
%                            'maxmin' or [xmin xmax] (default = 'maxmin')
%   cfg.ylim               = selection boundaries over second dimension in data (e.g., freq)
%                            'maxmin' or [xmin xmax] (default = 'maxmin')
%   cfg.zlim               = plotting limits for color dimension, 'maxmin', 'maxabs', 'zeromax', 'minzero', or [zmin zmax] (default = 'maxmin')
%   cfg.channel            = Nx1 cell-array with selection of channels (default = 'all'), see FT_CHANNELSELECTION for details
%   cfg.refchannel         = name of reference channel for visualising connectivity, can be 'gui'
%   cfg.baseline           = 'yes','no' or [time1 time2] (default = 'no'), see FT_TIMELOCKBASELINE or FT_FREQBASELINE
%   cfg.baselinetype       = 'absolute' or 'relative' (default = 'absolute')
%   cfg.trials             = 'all' or a selection given as a 1xN vector (default = 'all')
%   cfg.colormap           = any sized colormap, see COLORMAP
%   cfg.marker             = 'on', 'labels', 'numbers', 'off'
%   cfg.markersymbol       = channel marker symbol (default = 'o')
%   cfg.markercolor        = channel marker color (default = [0 0 0] (black))
%   cfg.markersize         = channel marker size (default = 2)
%   cfg.markerfontsize     = font size of channel labels (default = 8 pt)
%   cfg.highlight          = 'on', 'labels', 'numbers', 'off'
%   cfg.highlightchannel   =  Nx1 cell-array with selection of channels, or vector containing channel indices see FT_CHANNELSELECTION
%   cfg.highlightsymbol    = highlight marker symbol (default = 'o')
%   cfg.highlightcolor     = highlight marker color (default = [0 0 0] (black))
%   cfg.highlightsize      = highlight marker size (default = 6)
%   cfg.highlightfontsize  = highlight marker size (default = 8)
%   cfg.hotkeys            = enables hotkeys (up/down arrows) for dynamic colorbar adjustment
%   cfg.colorbar           = 'yes'
%                            'no' (default)
%                            'North'              inside plot box near top
%                            'South'              inside bottom
%                            'East'               inside right
%                            'West'               inside left
%                            'NorthOutside'       outside plot box near top
%                            'SouthOutside'       outside bottom
%                            'EastOutside'        outside right
%                            'WestOutside'        outside left
%   cfg.interplimits       = limits for interpolation (default = 'head')
%                            'electrodes' to furthest electrode
%                            'head' to edge of head
%   cfg.interpolation      = 'linear','cubic','nearest','v4' (default = 'v4') see GRIDDATA
%   cfg.style              = plot style (default = 'both')
%                            'straight' colormap only
%                            'contour' contour lines only
%                            'both' (default) both colormap and contour lines
%                            'fill' constant color between lines
%                            'blank' only the head shape
%   cfg.gridscale          = scaling grid size (default = 67)
%                            determines resolution of figure
%   cfg.shading            = 'flat' 'interp' (default = 'flat')
%   cfg.comment            = string 'no' 'auto' or 'xlim' (default = 'auto')
%                            'auto': date, xparam and zparam limits are printed
%                            'xlim': only xparam limits are printed
%   cfg.commentpos         = string or two numbers, position of comment (default 'leftbottom')
%                            'lefttop' 'leftbottom' 'middletop' 'middlebottom' 'righttop' 'rightbottom'
%                            'title' to place comment as title
%                            'layout' to place comment as specified for COMNT in layout
%                            [x y] coordinates
%   cfg.interactive        = Interactive plot 'yes' or 'no' (default = 'yes')
%                            In a interactive plot you can select areas and produce a new
%                            interactive plot when a selected area is clicked. Multiple areas
%                            can be selected by holding down the SHIFT key.
%   cfg.directionality     = '', 'inflow' or 'outflow' specifies for
%                            connectivity measures whether the inflow into a
%                            node, or the outflow from a node is plotted. The
%                            (default) behavior of this option depends on the dimor
%                            of the input data (see below).
%   cfg.layout             = specify the channel layout for plotting using one of
%                            the supported ways (see below).
%   cfg.interpolatenan     = string 'yes', 'no' (default = 'yes')
%                            interpolate over channels containing NaNs
%
% For the plotting of directional connectivity data the cfg.directionality
% option determines what is plotted. The default value and the supported
% functionality depend on the dimord of the input data. If the input data
% is of dimord 'chan_chan_XXX', the value of directionality determines
% whether, given the reference channel(s), the columns (inflow), or rows
% (outflow) are selected for plotting. In this situation the default is
% 'inflow'. Note that for undirected measures, inflow and outflow should
% give the same output. If the input data is of dimord 'chancmb_XXX', the
% value of directionality determines whether the rows in data.labelcmb are
% selected. With 'inflow' the rows are selected if the refchannel(s) occur in
% the right column, with 'outflow' the rows are selected if the
% refchannel(s) occur in the left column of the labelcmb-field. Default in
% this case is '', which means that all rows are selected in which the
% refchannel(s) occur. This is to robustly support linearly indexed
% undirected connectivity metrics. In the situation where undirected
% connectivity measures are linearly indexed, specifying 'inflow' or
% 'outflow' can result in unexpected behavior.
%
% The layout defines how the channels are arranged. You can specify the
% layout in a variety of ways:
%  - you can provide a pre-computed layout structure, see FT_PREPARE_LAYOUT
%  - you can give the name of an ascii layout file with extension *.lay
%  - you can give the name of an electrode file
%  - you can give an electrode definition, i.e. "elec" structure
%  - you can give a gradiometer definition, i.e. "grad" structure
% If you do not specify any of these and the data structure contains an
% electrode or gradiometer structure, that will be used for creating a
% layout. If you want to have more fine-grained control over the layout
% of the subplots, you should create your own layout file.
%
% See also FT_SINGLEPLOTER, FT_MULTIPLOTER, FT_SINGLEPLOTTFR, FT_MULTIPLOTTFR,
% FT_TOPOPLOTTFR, FT_PREPARE_LAYOUT

% Undocumented local options:
% cfg.labeloffset (offset of labels to their marker, default = 0.005)

% Copyright (C) 2005-2011, F.C. Donders Centre
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
% $Id: ft_topoplotER.m 9737 2014-07-16 15:50:21Z roboos $

revision = '$Id: ft_topoplotER.m 9737 2014-07-16 15:50:21Z roboos $';

% do the general setup of the function
ft_defaults
ft_preamble init
ft_preamble loadvar    varargin
ft_preamble provenance varargin
ft_preamble trackconfig
ft_preamble debug

% the abort variable is set to true or false in ft_preamble_init
if abort
  return
end

% make sure figure window titles are labeled appropriately, pass this onto the actual
% plotting function if we don't specify this, the window will be called
% 'ft_topoplotTFR', which is confusing to the user
cfg.funcname = mfilename;
if nargin > 1 && ~isfield(cfg, 'dataname')
  cfg.dataname = {inputname(2)};
  for k = 3:nargin
    cfg.dataname{end+1} = inputname(k);
  end
end

% prepare the layout, this should be done only once
cfg.layout = ft_prepare_layout(cfg, varargin{1});

% call the common function that is shared between ft_topoplotER and ft_topoplotTFR
cfg = topoplot_common(cfg, varargin{:});

% remove this field again, it is only used for figure labels
cfg = removefields(cfg, 'funcname');

% do the general cleanup and bookkeeping at the end of the function
ft_postamble trackconfig
ft_postamble previous varargin
ft_postamble provenance
ft_postamble debug

if ~nargout
  clear cfg
end
