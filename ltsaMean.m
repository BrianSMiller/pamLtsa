function output = ltsaMean(ltsa_lin, t, tOut, timeWindow_s)
% ltsaMean  Average a multi-band LTSA matrix into arbitrary time bins.
%
% Averages columns of ltsa_lin into bins centred on tOut, using a
% rectangular window of duration timeWindow_s seconds. Handles NaNs and
% irregular sampling. Much faster than looping over bands individually.
%
% Usage:
%   output = ltsaMean(ltsa_lin, t, tOut, timeWindow_s)
%
% Inputs:
%   ltsa_lin      nBands x nTimes matrix of linear (not dB) values
%   t             1 x nTimes vector of MATLAB datenums (input times)
%   tOut          1 x nOut vector of MATLAB datenums (output bin centres)
%   timeWindow_s  scalar window duration in seconds (e.g. 3*3600 for 3h)
%
% Output:
%   output        nBands x nOut matrix, NaN where no input samples fall
%                 within the window
%
% See also: timeMean, ltsaToBands

arguments
    ltsa_lin     (:,:) double
    t            (1,:) double
    tOut         (1,:) double
    timeWindow_s (1,1) double {mustBePositive}
end

hw     = (timeWindow_s / 2) / 86400;  % half-window in datenum units
nOut   = length(tOut);
nBands = size(ltsa_lin, 1);
output = nan(nBands, nOut);

for i = 1:nOut
    ix = abs(t - tOut(i)) <= hw & ~any(isnan(ltsa_lin), 1);
    if any(ix)
        output(:, i) = mean(ltsa_lin(:, ix), 2, 'omitnan');
    end
end