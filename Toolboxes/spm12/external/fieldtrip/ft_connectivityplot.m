function [cfg] = ft_connectivityplot(cfg, varargin)

% FT_CONNECTIVITYPLOT plots frequency-resolved connectivity between EEG/MEG
% channels. The data are rendered in a square grid of subplots and each
% subplot containing the connectivity spectrum.
%
% Use as
%   ft_connectivityplot(cfg, data)
%
% The input data is a structure containing the output to FT_CONNECTIVITYANALYSIS
% using a frequency domain metric of connectivity. Consequently the input
% data should have a dimord of 'chan_chan_freq'.
%
% The cfg can have the following options:
%   cfg.parameter   = string, the functional parameter to be plotted (default = 'cohspctrm')
%   cfg.xlim        = selection boundaries over first dimension in data (e.g., freq)
%                     'maxmin' or [xmin xmax] (default = 'maxmin')
%   cfg.zlim        = plotting limits for color dimension, 'maxmin', 'maxabs' or [zmin zmax] (default = 'maxmin')
%   cfg.channel     = list of channels to be included for the plotting (default = 'all'), see FT_CHANNELSELECTION for details
%
% See also FT_CONNECTIVITYANALYSIS, FT_CONNECTIVITYSIMULATION, FT_MULTIPLOTCC, FT_TOPOPLOTCC

% Copyright (C) 2011-2013, Jan-Mathijs Schoffelen
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
% $Id: ft_connectivityplot.m 9798 2014-09-15 08:06:26Z roboos $

revision = '$Id: ft_connectivityplot.m 9798 2014-09-15 08:06:26Z roboos $';

% do the general setup of the function
ft_defaults
ft_preamble init
ft_preamble provenance
ft_preamble trackconfig
ft_preamble debug

% the abort variable is set to true or false in ft_preamble_init
if abort
  return
end

% check if the input data is valid for this function
for i=1:length(varargin)
  varargin{i} = ft_checkdata(varargin{i});
end

% check if the input cfg is valid for this function
cfg = ft_checkconfig(cfg, 'renamed', {'zparam', 'parameter'});

% set the defaults
cfg.channel   = ft_getopt(cfg, 'channel',   'all');
cfg.parameter = ft_getopt(cfg, 'parameter', 'cohspctrm');
cfg.zlim      = ft_getopt(cfg, 'zlim',      'maxmin');
cfg.xlim      = ft_getopt(cfg, 'xlim',      'maxmin');
cfg.color     = ft_getopt(cfg, 'color',     'brgkywrgbkywrgbkywrgbkyw');

% Get physical min/max range of x:
if ischar(cfg.xlim) && strcmp(cfg.xlim,'maxmin')
  xmin = inf;
  xmax = -inf;
  for k = 1:numel(varargin)
    xmin = min(xmin,varargin{k}.freq(1));
    xmax = max(xmax,varargin{k}.freq(end));
  end
else
  xmin = cfg.xlim(1);
  xmax = cfg.xlim(2);
end
cfg.xlim = [xmin xmax];

% Get physical min/max range of z:
if ischar(cfg.zlim) && strcmp(cfg.zlim,'maxmin')
  zmin = inf;
  zmax = -inf;
  for k = 1:numel(varargin)
    zmin = min(zmin,min(varargin{k}.(cfg.parameter)(:)));
    zmax = max(zmax,max(varargin{k}.(cfg.parameter)(:)));
  end
elseif ischar(cfg.zlim) && strcmp(cfg.zlim,'maxabs')
  zmax = -inf;
  for k = 1:numel(varargin)
    zmax = max(zmax,max(abs(varargin{k}.(parameter)(:))));
  end
  zmin = -zmax;
else
  zmin = cfg.zlim(1);
  zmax = cfg.zlim(2);
end
cfg.zlim = [zmin zmax];

% make the function recursive if numel(varargin)>1
% FIXME check explicitly which channels belong together
if numel(varargin)>1
  data = varargin{1};
  tmpcfg = cfg;
  if ischar(cfg.parameter)
    % do nothing
  elseif iscell(cfg.parameter)
    tmpcfg.parameter = cfg.parameter{1};
  end
  ft_connectivityplot(tmpcfg, data);
  tmpcfg = cfg;
  
  % FIXME also set the zlim scale to be consistent across inputs
  for k = 2:numel(varargin)
    tmpcfg.color   = tmpcfg.color(2:end);
    tmpcfg.holdfig = 1;
    if ischar(cfg.parameter)
      % do nothing
    elseif iscell(cfg.parameter)
      tmpcfg.parameter = cfg.parameter{k};
    end
    ft_connectivityplot(tmpcfg, varargin{k});
  end
  return;
else
  data = varargin{1};
end

if strcmp(data.dimord, 'chan_chan_freq')
  % that's ok
elseif strcmp(data.dimord, 'chancmb_freq')
  % convert into 'chan_chan_freq'
  data = ft_checkdata(data, 'cmbrepresentation', 'full');
else
  error('the data should have a dimord of %s or %s', 'chan_chan_freq', 'chancmb_freq');
end

if ~isfield(data, cfg.parameter)
  error('the data does not contain the requested parameter %s', cfg.parameter);
end

cfg.channel = ft_channelselection(cfg.channel, data.label);

tmpcfg         = [];
tmpcfg.channel = cfg.channel;
tmpcfg.foilim  = cfg.xlim;
data           = ft_selectdata(tmpcfg, data);

% restore the provenance information
[cfg, data] = rollback_provenance(cfg, data);


dat   = data.(cfg.parameter);
nchan = numel(data.label);
nfreq = numel(data.freq);

if (isfield(cfg, 'holdfig') && cfg.holdfig==0) || ~isfield(cfg, 'holdfig')
  cla;
  hold on;
end

for k = 1:nchan
  for m = 1:nchan
    if k~=m
      ix  = k;
      iy  = nchan - m + 1;
      % use the convention of the row-channel causing the column-channel
      tmp = reshape(dat(m,k,:), [nfreq 1]);
      ft_plot_vector(tmp, 'width', 1, 'height', 1, 'hpos', ix.*1.2, 'vpos', iy.*1.2, 'vlim', cfg.zlim, 'box', 'yes', 'color', cfg.color(1));
      if k==1,
        % first column, plot scale on y axis
        fontsize = 10;
        ft_plot_text( ix.*1.2-0.5,iy.*1.2-0.5,num2str(cfg.zlim(1),3),'HorizontalAlignment','Right','VerticalAlignment','Middle','Fontsize',fontsize,'Interpreter','none');
        ft_plot_text( ix.*1.2-0.5,iy.*1.2+0.5,num2str(cfg.zlim(2),3),'HorizontalAlignment','Right','VerticalAlignment','Middle','Fontsize',fontsize,'Interpreter','none');
      end
      if m==nchan,
        % bottom row, plot scale on x axis
        fontsize = 10;
        ft_plot_text( ix.*1.2-0.5,iy.*1.2-0.5,num2str(data.freq(1  ),3),'HorizontalAlignment','Center','VerticalAlignment','top','Fontsize',fontsize,'Interpreter','none');
        ft_plot_text( ix.*1.2+0.5,iy.*1.2-0.5,num2str(data.freq(end),3),'HorizontalAlignment','Center','VerticalAlignment','top','Fontsize',fontsize,'Interpreter','none');
      end
    end
  end
end

% add channel labels on grand X and Y axes
for k = 1:nchan
  ft_plot_text(0,       (nchan + 1 - k).*1.2, data.label{k}, 'Interpreter', 'none');
  ft_plot_text(k.*1.2,  (nchan + 1)    .*1.2, data.label{k}, 'Interpreter', 'none');
end

% add 'from' and 'to' labels
ft_plot_text(-0.5,           (nchan + 1)/1.7, '\it{from}', 'rotation', 90);
ft_plot_text((nchan + 1)/1.7, (nchan + 1)*1.2+0.4, '\it{to}');

axis([-0.2 (nchan+1).*1.2+0.2 0 (nchan+1).*1.2+0.2]);
axis off;

set(gcf, 'color', [1 1 1]);

% do the general cleanup and bookkeeping at the end of the function
ft_postamble debug
ft_postamble trackconfig
ft_postamble provenance
ft_postamble previous varargin
