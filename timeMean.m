% function output = timeMean(signal, signalTime, timeVector, timeWindow)
% Compute the moving average for a signal using timeWindow seconds samples
% for the duration of points to average.  Moving average is a type of low pass
% digital filter. Note: The first and last points will be biased towards
% later points up to the timeWindow. 
%
% This function is intended for use with signals that have been irregularly
% sampled in time. For regularly sampled signals see movAvg.
% 
% timeVector is a 1xN array containing matlab DATENUMS, while TIMEWINDOW is
% the duration of the moving average 'box' in SECONDS.
%
% modified on 2009-01-14 to ignore NaNs in the signal vector
function output = timeMean(signal, signalTime, timeVector, timeWindow)
len = length(timeVector);
output = nan(size(timeVector));

for count = 1:len
    t = timeVector(count);
    ix = find((abs(t-signalTime)*86400 <= timeWindow) & ~isnan(signal));
    if ~isempty(ix) 
        output(count) = nanmean(signal(ix));
    end
end
output = output(:);