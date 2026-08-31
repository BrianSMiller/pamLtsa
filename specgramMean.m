% function output = specgramMean(specgram, signalTime, timeVector, timeWindow)
% Compute the moving average for a signal using timeWindow seconds samples
% for the duration of points to average.  Moving average is a type of low pass
% digital filter. Note: The first and last points will be biased towards
% later points up to the timeWindow. 
%
% This is the spectrogram equivalent of timeMean: specgram is a
% numFreqs x numSlices matrix and each frequency row is averaged
% independently, returning a numFreqs x length(timeVector) matrix.
%
% This function is intended for use with spectrograms that have been
% irregularly sampled in time.
% 
% timeVector is a 1xN array containing matlab DATENUMS, while TIMEWINDOW is
% the duration of the moving average 'box' in SECONDS.
%
% modified on 2009-01-14 to ignore NaNs in the signal vector
function output = specgramMean(specgram, signalTime, timeVector, timeWindow)
len = length(timeVector);
siz = size(specgram);
output = nan(siz(1), len);

for count = 1:len
    t = timeVector(count);
    ix = find((abs(t-signalTime)*86400 <= timeWindow));
    if ~isempty(ix) 
        output(:,count) = mean(specgram(:,ix),2);
    end
end
