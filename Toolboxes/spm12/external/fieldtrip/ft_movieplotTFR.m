function [cfg] = ft_movieplotTFR(cfg, data)

% FT_MOVIEPLOTTFR makes a movie of a time frequency representation of power or coherence 
%
% Use as
%   ft_movieplotTFR(cfg, data)
% where the input data comes from FT_FREQANALYSIS or FT_FREQDESCRIPTIVES and the
% configuration is a structure that can contain
%   cfg.parameter    = string, parameter that is color coded (default = 'avg')
%   cfg.xlim         = selection boundaries over first dimension in data (e.g., time)
%                          'maxmin' or [xmin xmax] (default = 'maxmin')
%   cfg.ylim         = selection boundaries over second dimension in data (e.g., freq)
%                          'maxmin' or [xmin xmax] (default = 'maxmin')
%   cfg.zlim         = plotting limits for color dimension, 'maxmin',
%                          'maxabs', 'zeromax', 'minzero', or [zmin zmax] (default = 'maxmin')
%   cfg.samperframe  = number, samples per fram (default = 1)
%   cfg.framespersec = number, frames per second (default = 5)
%   cfg.framesfile   = [] (optional), no file saved, or 'string', filename of saved frames.mat (default = []);
%   cfg.moviefreq    = number, movie frames are all time points at the fixed frequency moviefreq (default = []);
%   cfg.movietime    = number, movie frames are all frequencies at the fixed time movietime (default = []);
%   cfg.layout       = specification of the layout, see below
%   cfg.interactive  = 'no' or 'yes', make it interactive
%
% the layout defines how the channels are arranged. you can specify the
% layout in a variety of ways:
%  - you can provide a pre-computed layout structure (see prepare_layout)
%  - you can give the name of an ascii layout file with extension *.mat
%  - you can give the name of an electrode file
%  - you can give an electrode definition, i.e. "elec" structure
%  - you can give a gradiometer definition, i.e. "grad" structure
% if you do not specify any of these and the data structure contains an
% electrode or gradiometer structure, that will be used for creating a
% layout. if you want to have more fine-grained control over the layout
% of the subplots, you should create your own layout file.
%
% to facilitate data-handling and distributed computing you can use
%   cfg.inputfile   =  ...
% if you specify this option the input data will be read from a *.mat
% file on disk. this mat files should contain only a single variable named 'data',
% corresponding to the input structure.

% Copyright (c) 2009, Ingrid Nieuwenhuis
% Copyright (c) 2011, jan-Mathijs Schoffelen, Robert Oostenveld, Cristiano Micheli
%
% this file is part of fieldtrip, see http://www.ru.nl/neuroimaging/fieldtrip
% for the documentation and details.
%
%    fieldtrip is free software: you can redistribute it and/or modify
%    it under the terms of the gnu general public license as published by
%    the free software foundation, either version 3 of the license, or
%    (at your option) any later version.
%
%    fieldtrip is distributed in the hope that it will be useful,
%    but without any warranty; without even the implied warranty of
%    merchantability or fitness for a particular purpose.  see the
%    gnu general public license for more details.
%
%    you should have received a copy of the gnu general public license
%    along with fieldtrip. if not, see <http://www.gnu.org/licenses/>.
%
% $id: ft_movieploter.m 4354 2011-10-05 15:06:02z crimic $

revision = '$Id: ft_movieplotTFR.m 9521 2014-05-14 09:45:42Z roboos $';

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

% check if the input data is valid for this function
% note that this function is also called from ft_movieplotER
data = ft_checkdata(data, 'datatype', {'timelock', 'freq'});

% check if the input cfg is valid for this function
cfg = ft_checkconfig(cfg, 'renamedval', {'zlim',  'absmax',  'maxabs'});
cfg = ft_checkconfig(cfg, 'renamed',    {'zparam', 'parameter'});
cfg = ft_checkconfig(cfg, 'deprecated', {'xparam'});

% set the defaults
cfg.xlim          = ft_getopt(cfg, 'xlim', 'maxmin');
cfg.ylim          = ft_getopt(cfg, 'ylim', 'maxmin');
cfg.zlim          = ft_getopt(cfg, 'zlim', 'maxmin');
cfg.parameter     = ft_getopt(cfg, 'parameter', 'powspctrm'); % use power as default
cfg.inputfile     = ft_getopt(cfg, 'inputfile',    []);
cfg.samperframe   = ft_getopt(cfg, 'samperframe',  1);
cfg.framespersec  = ft_getopt(cfg, 'framespersec', 5);
cfg.framesfile    = ft_getopt(cfg, 'framesfile',   []);
cfg.moviefreq     = ft_getopt(cfg, 'moviefreq', []);
cfg.movietime     = ft_getopt(cfg, 'movietime', []);
cfg.movierpt      = ft_getopt(cfg, 'movierpt', 1);
cfg.interactive   = ft_getopt(cfg, 'interactive', 'yes');
dointeractive     = istrue(cfg.interactive);

xparam = 'time';
if isfield(data, 'freq')
  yparam = 'freq';
end

% read or create the layout that will be used for plotting:
layout = ft_prepare_layout(cfg);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% the actual computation is done in the middle part
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

xvalues   = data.(xparam);
parameter = data.(cfg.parameter);
if exist('yparam', 'var')
  yvalues = data.(yparam);
end

% check consistency of xparam and yparam
% NOTE: i set two different defaults for the 'chan_time' and the 'chan_freq_time' case
if isfield(data,'dimord')
  if strcmp(data.dimord,'chan_freq_time')
    if length(xvalues)~=size(parameter,3)
      error('inconsistent size of "%s" compared to "%s"', cfg.parameter, xparam);
    end
    if length(yvalues)~=size(parameter,2)
      error('inconsistent size of "%s" compared to "%s"', cfg.parameter, yparam);
    end
  elseif strcmp(data.dimord,'chan_time')
    if length(xvalues)~=size(parameter,2)
      error('inconsistent size of "%s" compared to "%s"', cfg.parameter, xparam);
    end    
  else
    error('input data is incompatible')
  end
end

if ischar(cfg.xlim) && strcmp(cfg.xlim, 'maxmin')
  cfg.xlim    = [];
  cfg.xlim(1) = min(xvalues);
  cfg.xlim(2) = max(xvalues);
end

xbeg = nearest(xvalues, cfg.xlim(1));
xend = nearest(xvalues, cfg.xlim(2));

% update the configuration
cfg.xlim = xvalues([xbeg xend]);

if exist('yparam', 'var')
  if ischar(cfg.ylim) && strcmp(cfg.ylim, 'maxmin')
    cfg.ylim    = [];
    cfg.ylim(1) = min(yvalues);
    cfg.ylim(2) = max(yvalues);
  end
  ybeg = nearest(yvalues, cfg.ylim(1));
  yend = nearest(yvalues, cfg.ylim(2));
  % update the configuration
  cfg.ylim = yvalues([ybeg yend]);
  hasyparam = true;
else
  % this allows us not to worry about the yparam any more
  yvalues = nan;
  yparam  = nan;
  ybeg = 1;
  yend = 1;
  cfg.ylim = [];
  hasyparam = false;
end


% select the channels in the data that match with the layout:
[seldat, sellay] = match_str(data.label, layout.label);
if isempty(seldat)
  error('labels in data and labels in layout do not match');
end

% make a subselection of the data
xvalues = xvalues(xbeg:xend);
yvalues = yvalues(ybeg:yend);
if all(isnan(yvalues))
  parameter = parameter(seldat, xbeg:xend);  
else
  parameter = parameter(seldat, ybeg:yend, xbeg:xend);
end
clear xbeg xend ybeg yend

% get the x and y coordinates and labels of the channels in the data
chanx = layout.pos(sellay,1);
chany = layout.pos(sellay,2);

% get the z-range
if ischar(cfg.zlim) && strcmp(cfg.zlim, 'maxmin')
  cfg.zlim    = [];
  cfg.zlim(1) = min(parameter(:));
  cfg.zlim(2) = max(parameter(:));
elseif ischar(cfg.zlim) && strcmp(cfg.zlim,'maxabs')
  cfg.zlim     = [];
  cfg.zlim(1)  = -max(abs(parameter(:)));
  cfg.zlim(2)  =  max(abs(parameter(:)));
elseif ischar(cfg.zlim) && strcmp(cfg.zlim,'zeromax')
  cfg.zlim     = [];
  cfg.zlim(1)  = 0;
  cfg.zlim(2)  = max(parameter(:));
elseif ischar(cfg.zlim) && strcmp(cfg.zlim,'minzero')
  cfg.zlim     = [];
  cfg.zlim(1)  = min(parameter(:));
  cfg.zlim(2)  = 0;
end

h = gcf;
pos = get(gcf, 'position');
set(h, 'toolbar', 'figure');

if dointeractive
  
  % add the gui elements for changing the speed
  p = uicontrol('style', 'text');
  set(p, 'position', [20 75 50 20]);
  set(p, 'string', 'speed')
  button_slower = uicontrol('style', 'pushbutton');
  set(button_slower, 'position', [75 75 20 20]);
  set(button_slower, 'string', '-')
  set(button_slower, 'callback', @cb_speed);
  button_faster = uicontrol('style', 'pushbutton');
  set(button_faster, 'position', [100 75 20 20]);
  set(button_faster, 'string', '+')
  set(button_faster, 'callback', @cb_speed);
  
  % add the gui elements for changing the color limits
  p = uicontrol('style', 'text');
  set(p, 'position', [20 100 50 20]);
  set(p, 'string', 'zlim')
  button_slower = uicontrol('style', 'pushbutton');
  set(button_slower, 'position', [75 100 20 20]);
  set(button_slower, 'string', '-')
  set(button_slower, 'callback', @cb_zlim);
  button_faster = uicontrol('style', 'pushbutton');
  set(button_faster, 'position', [100 100 20 20]);
  set(button_faster, 'string', '+')
  set(button_faster, 'callback', @cb_zlim);
  
  sx = uicontrol('style', 'slider');
  set(sx, 'position', [20 5 pos(3)-160 20]);
  % note that "sx" is needed further down
  
  sy = uicontrol('style', 'slider');
  set(sy, 'position', [20 30 pos(3)-160 20]);
  % note that "sy" is needed further down
  
  p = uicontrol('style', 'pushbutton');
  set(p, 'position', [20 50 50 20]);
  set(p, 'string', 'play')
  % note that "p" is needed further down
  
  hx = uicontrol('style', 'text');
  set(hx, 'position', [pos(3)-140 5 120 20]);
  set(hx, 'string', sprintf('%s = ', xparam));
  set(hx, 'horizontalalignment', 'left');
  
  hy = uicontrol('style', 'text');
  set(hy, 'position', [pos(3)-140 30 120 20]);
  set(hy, 'string', sprintf('%s = ', yparam));
  set(hy, 'horizontalalignment', 'left');
  
  if ~hasyparam
    set(hy, 'visible', 'off')
    set(sy, 'visible', 'off')
  end
  
  t = timer;
  set(t, 'timerfcn', {@cb_timer, h}, 'period', 0.1, 'executionmode', 'fixedspacing');
  
  % collect the data and the options to be used in the figure
  opt.lay   = layout;
  opt.chanx = chanx;
  opt.chany = chany;
  opt.xvalues  = xvalues; % freq
  opt.yvalues  = yvalues; % time
  opt.xparam = xparam;
  opt.yparam = yparam;
  opt.dat   = parameter;
  opt.zlim  = cfg.zlim;
  opt.speed = 1;
  opt.cfg   = cfg;
  opt.sx    = sx; % slider freq
  opt.sy    = sy; % slider time
  opt.p     = p;
  opt.t     = t;
  if ~hasyparam
    opt.timdim = 2;
  else
    opt.timdim = 3;
  end
  [dum, hs] = ft_plot_topo(chanx, chany, zeros(numel(chanx),1), 'mask', layout.mask, 'outline', layout.outline, 'interpmethod', 'v4', 'interplim', 'mask');
  caxis(cfg.zlim);
  axis off;
  
  % add sum stuff at a higher level for quicker access in the callback
  % routine
  opt.xdata   = get(hs, 'xdata');
  opt.ydata   = get(hs, 'ydata');
  opt.nanmask = get(hs, 'cdata');
  
  % add the handle to the mesh
  opt.hs  = hs;
  
  % add the text-handle to the guidata
  opt.hx  = hx;
  opt.hy  = hy;
  
  guidata(h, opt);
  
  % from now it is safe to hand over the control to the callback function
  set(sx, 'callback', @cb_slider);
  set(sy, 'callback', @cb_slider);
  % from now it is safe to hand over the control to the callback function
  set(p, 'callback', @cb_playbutton);
  
else
  % non interactive mode
  [tmp, hs] = ft_plot_topo(chanx, chany, zeros(numel(chanx),1), 'mask', layout.mask, 'outline', layout.outline, 'interpmethod', 'v4');
  caxis(cfg.zlim);
  axis off;

  xdata   = get(hs, 'xdata');
  ydata   = get(hs, 'ydata');
  nanmask = get(hs, 'cdata');
  
  % frequency/time selection
  if exist('yparam', 'var') && any(~isnan(yvalues)) 
    if ~isempty(cfg.movietime)
      indx = cfg.movietime;
      for iFrame = 1:floor(size(parameter, 2)/cfg.samperframe)
        indy = ((iFrame-1)*cfg.samperframe+1):iFrame*cfg.samperframe;
        datavector = squeeze(mean(parameter(:, indy,indx), 2));
        datamatrix = griddata(chanx, chany, datavector, xdata, ydata, 'v4');
        set(hs, 'cdata',  datamatrix + nanmask);
        F(iFrame) = getframe;
      end 
    elseif ~isempty(cfg.moviefreq)
      indy = cfg.moviefreq;
      for iFrame = 1:floor(size(parameter, 3)/cfg.samperframe)
        indx = ((iFrame-1)*cfg.samperframe+1):iFrame*cfg.samperframe;
        datavector = squeeze(mean(parameter(:, indy,indx), 3));
        datamatrix = griddata(chanx, chany, datavector, xdata, ydata, 'v4');
        set(hs, 'cdata',  datamatrix + nanmask);
        F(iFrame) = getframe;
      end      
    else
      error('Either moviefreq or movietime should contain a bin number')
    end
  else
    for iFrame = 1:floor(size(parameter, 2)/cfg.samperframe)
      indx = ((iFrame-1)*cfg.samperframe+1):iFrame*cfg.samperframe;
      datavector = mean(parameter(:, indx), 2);    
      datamatrix = griddata(chanx, chany, datavector, xdata, ydata, 'v4');
      set(hs, 'cdata',  datamatrix + nanmask);
      F(iFrame) = getframe;
    end
  end
   
  % save movie
  if ~isempty(cfg.framesfile)
    save(cfg.framesfile, 'F');
  end
  % play movie
  movie(F, cfg.movierpt, cfg.framespersec);
  
end

% do the general cleanup and bookkeeping at the end of the function
ft_postamble debug
ft_postamble trackconfig
ft_postamble provenance
ft_postamble previous data


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% subfunction
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function cb_slider(h, eventdata)
  opt = guidata(h);

  xdim = opt.timdim;
  valx = get(opt.sx, 'value');
  valx = round(valx*(size(opt.dat,xdim)-1))+1;
  valx = min(valx, size(opt.dat,xdim));
  valx = max(valx, 1);
  if valx>size(opt.dat,opt.timdim)
    valx = size(opt.dat,opt.timdim)-1;
  end

if length(size(opt.dat))>2
  ydim = 2;
  valy = get(opt.sy, 'value');
  valy = round(valy*(size(opt.dat,ydim)-1))+1;
  valy = min(valy, size(opt.dat,ydim));
  valy = max(valy, 1);

  set(opt.hx, 'string', sprintf('%s = %f\n', opt.xparam, opt.xvalues(valx)));
  set(opt.hy, 'string', sprintf('%s = %f\n', opt.yparam, opt.yvalues(valy)));

  % update data, interpolate and render
  datamatrix = griddata(opt.chanx, opt.chany, opt.dat(:,valy,valx), opt.xdata, opt.ydata, 'v4');
else
  set(opt.hx, 'string', sprintf('%s = %f\n', opt.xparam, opt.xvalues(valx)));
  % update data, interpolate and render
  datamatrix = griddata(opt.chanx, opt.chany, opt.dat(:,valx), opt.xdata, opt.ydata, 'v4');  
end
set(opt.hs, 'cdata',  datamatrix + opt.nanmask);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% subfunction
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function cb_playbutton(h, eventdata)
if ~ishandle(h)
  return
end
opt = guidata(h);
switch get(h, 'string')
  case 'play'
    set(h, 'string', 'stop');
    start(opt.t);
  case 'stop'
    set(h, 'string', 'play');
    stop(opt.t);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% subfunction
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function cb_timer(obj, event, h)
if ~ishandle(h)
  return
end
opt = guidata(h);
delta = opt.speed/size(opt.dat,opt.timdim);
val = get(opt.sx, 'value');
val = val + delta;
% to avoid the slider to go out of range when the speed is too high
if val+delta>2
  val = get(opt.sx, 'value');
end
if val>1
  val = val-1; 
end
set(opt.sx, 'value', val);
cb_slider(h);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% subfunction
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function cb_zlim(h, eventdata)
if ~ishandle(h)
  return
end
opt = guidata(h);
switch get(h, 'string')
  case '+'
    caxis(caxis*sqrt(2));
  case '-'
    caxis(caxis/sqrt(2));
end % switch
guidata(h, opt);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% subfunction
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function cb_speed(h, eventdata)
if ~ishandle(h)
  return
end
opt = guidata(h);
switch get(h, 'string')
  case '+'
    opt.speed = opt.speed*sqrt(2);
  case '-'
    opt.speed = opt.speed/sqrt(2);
%     opt.speed = max(opt.speed, 1); % should not be smaller than 1
end % switch
guidata(h, opt);
