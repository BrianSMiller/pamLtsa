

% There are no more user adjustable parameters below this line
for i = 1:length(fileNames);
    fullName = [pathName fileNames(i).name];
    fileInfo(i) = readXwavHeader(fullName);
end

% Calculate FFT lengths
sampleRate = fileInfo(1).sampleRate; % Assume all files are at same rate
b = nextpow2(sampleRate/freqResolution);
nfft = 2^b;
nSamplesPerAverage = durationOfAverage * sampleRate;

% Pre-allocate arrays for speed
startDate = min([fileInfo.startDate]);
[endDate lastFileIx] = max([fileInfo.startDate]);
endDate = endDate + (fileInfo(lastFileIx).numberOfSamples/sampleRate/86400);
totalDuration = (endDate - startDate)*86400; % in seconds

numberOfAverages = ceil(totalDuration/durationOfAverage);

% Initialize some arrays to speed things up
audio = zeros(nSamplesPerAverage,1);
[pxx,freqs] = pwelch(audio,nfft,noverlap,nfft,sampleRate);

numFreqs = length(freqs);

dataSize = numberOfAverages * numFreqs
ltsa = nan(numFreqs,numberOfAverages);

tStart = fileInfo(1).startDate;     % datenum
tIncrement = durationOfAverage/86400;% days
tEnd = fileInfo(end).endDate;       % datenum 
t = tStart:tIncrement:tEnd;

% Compute the PSD for each time slice
tic;
parfor i = 1:numberOfAverages-1
    try
    avgStart = t(i);
    avgEnd = t(i+1);
%     [audNoise weighting] = getAudioFromFiles(fileInfo,avgStart,avgEnd);
    [audio weighting] = getAudioFromFiles(fileInfo,avgStart,avgEnd,exclusions);
    if length(audio) < nfft
        continue
    end
    [ltsa(:,i),freqs] = pwelch(audio,nfft,noverlap,nfft,sampleRate);
    
    if rem(i,10) == 0;
        disp(sprintf('%g/%g completed. Elapsed time is %g seconds',i,numberOfAverages,toc));
    end
    catch
        continue
    end
end

% Write the PSD to a file
save(saveFile,'t','freqs','ltsa');

% Plot the PSD
% mag = 20*log10(abs(ltsa));
% h = pcolor(t,freqs,mag);
% set(h,'lineStyle','none');
% datetick('x','mmm');
% ylabel('Frequency (Hz)');