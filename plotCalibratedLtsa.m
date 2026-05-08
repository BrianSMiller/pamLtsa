function h = plotCalibratedLtsa(data, timeStride, varargin)
% plotCalibratedLtsa  Plot a calibrated long-term spectral average.
%
% Example usage:
%   data = loadCalibratedLtsa('kerguelen2020');
%   plotCalibratedLtsa(data);
%
%   % Inside a tiledlayout:
%   ax = nexttile;
%   plotCalibratedLtsa(data, 1, 'ax', ax);

if nargin < 2 || isempty(timeStride)
    timeStride = 1;
end

p = inputParser;
addParameter(p, 'ax',           [],                    @(x) isa(x,'matlab.graphics.axis.Axes'));
addParameter(p, 'startIx',      1);
addParameter(p, 'endIx',        length(data.t));
addParameter(p, 'ltsaFloor',    60);
addParameter(p, 'dynamicRange', 50);
addParameter(p, 'freqLimits',   [5 max(data.freq)]);
parse(p, varargin{:});

ax           = p.Results.ax;
startIx      = p.Results.startIx;
endIx        = p.Results.endIx;
ltsaFloor    = p.Results.ltsaFloor;
dynamicRange = p.Results.dynamicRange;
freqLimits   = p.Results.freqLimits;

% Subset data
data.t    = data.t(startIx:timeStride:endIx);
data.ltsa = data.ltsa(:, startIx:timeStride:endIx);

% Use provided axes or current axes
if isempty(ax)
    ax = gca;
end

h = surf(ax, data.t, data.freq, data.ltsa);
set(h, 'LineStyle', 'none');
set(ax, 'YScale', 'log', ...
    'CLim', [ltsaFloor, ltsaFloor + dynamicRange], ...
    'Layer', 'top');
ylabel(ax, 'Frequency (Hz)');
datetick(ax, 'x', 'mmm');
view(ax, 2);
axis(ax, 'tight');
ylim(ax, freqLimits);
grid(ax, 'on');
