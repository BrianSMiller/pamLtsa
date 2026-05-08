function wavFolderToLtsa_parallel(saveFile, ...
    fileInfo, ...
    durationOfAverage, ...
    freqResolution, ...
    noverlap, ...
    exclusions, ...
    clickSuppressionThreshold, ...
    clickSuppressionAmount)       
% Given soundFolder, calculate the long-term spectral average (LTSA)
% of these files. The LTSA is similar to a spectrogram, but each slice is
% comprised of a power-spectral density average (e.g. using Welch's method)
% instead of an FFT. For more information on LTSAs see:
%   http://cetus.ucsd.edu/technologies_LTSA.html
% Instead of operating on a vector of acoustic data, wavFolderToLtsa 
% operates on a soundFolder (e.g. the output of the wavFolderInfo). 
% see also: soundFolder, wavFolderInfo,  getAudioFromFiles, pwelch,
%           spectrogram
% FILEINFO is the output data structure from a soundFolder 
% DURATIONOFAVERAGE is the duration in seconds of each LTSA slice
% NOVERLAP is the amount of overlap used when calculating the PSD (NOT the
%   amount of overlap between slices). ***NOVERLAP TO BE REMOVED???
% FREQRESOLUTION determines the freuquency resolution in Hz for the LTSA
% EXCLUSIONS is an Nx2 array of datenums, and each row corresponds to a
% span of time that will be excluded from analysis. Column 1 contains the
% start time of the exclusion, and column 2 contains the end time of the
% exclusion.

if nargin < 7
    clickSuppressionThreshold = 3; % Standard deviations
end
if nargin < 8
    clickSuppressionAmount = 1000; 
end

%% Calculate nearest power of 2 FFT lengths needed to achieve the specified
%  freqResolution
sampleRate = fileInfo(1).sampleRate; % Assume all files are at same rate
b = nextpow2(sampleRate/freqResolution);
nfft = 2^b;
nSamplesPerAverage = durationOfAverage * sampleRate;

% Pre-allocate arrays for speed
startDate = min([fileInfo.startDate]);
[endDate, lastFileIx] = max([fileInfo.startDate]);
endDate = endDate + (fileInfo(lastFileIx).numberOfSamples/sampleRate/86400);
totalDuration = (endDate - startDate)*86400; % in seconds

numberOfAverages = ceil(totalDuration/durationOfAverage);

% Initialize some arrays to speed things up
audio = zeros(nSamplesPerAverage,1);
[~,freqs] = pwelch(audio,nfft,noverlap,nfft,sampleRate);

numFreqs = length(freqs);

% dataSize = numberOfAverages * numFreqs;
ltsa = nan(numFreqs,numberOfAverages);

tStart = fileInfo(1).startDate;     % datenum
tIncrement = durationOfAverage/86400;% days
tEnd = fileInfo(end).endDate;       % datenum 
t = tStart:tIncrement:tEnd;

%% Compute the PSD for each time slice
tic;

if isempty(gcp('nocreate')); parpool('Processes',feature('numcores')-1); end
ppm = ParforProgMon('LTSA Progress: ',numberOfAverages-1,100);

% Assign start and end vectors so t won't be a broadcast variable
tStart = t(1:end-1);
tEnd = t(2:end);
tic;
parfor i = 1:numberOfAverages-1

    try
        avgStart = tStart(i);
        avgEnd = tEnd(i);%     [audNoise weighting] = getAudioFromFiles(fileInfo,avgStart,avgEnd);
        [audio, ~] = getAudioFromFiles(fileInfo,avgStart,avgEnd,exclusions);
        audio = removeClicks(audio, ...
            clickSuppressionThreshold, clickSuppressionAmount);
        if length(audio) < nfft
            continue
        end
        [ltsa(:,i),freqs] = pwelch(audio,nfft,noverlap,nfft,sampleRate);

        if rem(i,100)==0 || i==nDet
            ppm.increment();
        end

    catch
        % If an error occurs, save the results to disk anyway
%         save(saveFile,'t','freqs','ltsa','fileInfo','i','nfft','noverlap','numberOfAverages');
        continue
    end
end
toc
size(ltsa);
% Write the PSD to a file
save(saveFile,'t','freqs','ltsa');

%% Plot the PSD
% mag = 20*log10(abs(ltsa));
% h = pcolor(t,freqs,mag);
% set(h,'lineStyle','none');
% datetick('x','mm/dd');
% ylabel('Frequency (Hz)');