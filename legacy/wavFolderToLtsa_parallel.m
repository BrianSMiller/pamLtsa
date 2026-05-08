function [ltsa, t, freq] = wavFolderToLtsa_parallel(saveFile, fileInfo,...
    durationOfAverage, freqResolution, noverlap, exclusions, channel)       
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
%   span of time that will be excluded from analysis. Column 1 contains the
%   start time of the exclusion, and column 2 contains the end time of the
% exclusion.
% CHANNEL is a scalar default=1; (TODO: allow multiple channels; presently 
%   single channel only).

%% Calculate nearest power of 2 FFT lengths needed to achieve the specified
%  freqResolution
sampleRate = fileInfo(1).sampleRate; % Assume all files are at same rate
b = nextpow2(sampleRate/freqResolution);
nfft = 2^b;
nSamplesPerAverage = durationOfAverage * sampleRate;

if nargin < 7
   channel = 1; % TODO fix from running only 1 chan of multichannel wav to work for all
end

% Pre-allocate arrays for speed
startDate = dateshift(datetime( ...
    min([fileInfo.startDate]),'ConvertFrom','datenum'),"start","hour");
endDate = dateshift(datetime(...
    max([fileInfo.startDate]),'convertFrom','datenum'),'end','hour');
t = datenum(startDate:seconds(durationOfAverage):endDate);

numberOfAverages = length(t)-1;

% Initialize some arrays to speed things up
audio = zeros(nSamplesPerAverage,1);
[~,freqs] = pwelch(audio,nfft,noverlap,nfft,sampleRate);

numFreqs = length(freqs);

% dataSize = numberOfAverages * numFreqs;
ltsa = nan(numFreqs,numberOfAverages);
% t_ltsa = ltsa; % Temporary ltsa for parfor loop

% Assume file doesn't exist and all times/columns are missing;
% missing = 1:numberOfAverages;

% Assign start and end vectors so t won't be a broadcast variable
tStart = t(1:end-1);
tEnd = t(2:end);

% 
% % Check if file exists and handle gracefully if it does with warning 
% if exist(saveFile,"file")==2
%     % Warn that file exists, check for missing columns, try to fix?
%     warning('wavFolderToLtsa:outpuFileExists','Save file %s already exists',saveFile);
%     tNew = t;
%     load(saveFile,'t','freqs','ltsa');
%     % Check whether saved times are different than requested
%     if any(size(t)~=size(tNew)) || any(t ~= tNew)
%         error('wavFolderToLtsa:savedTimesDoNotMatch', ...
%             ['Saved time vector does not match requested.\n',...
%             'Choose a different file name or delete save file and retry.'])
%         return
%     end
%     % missing times/columns in LTSA will have more than 1 or 2 nan
%     missing = find(sum(isnan(ltsa))>3); 
%     t_ltsa = ltsa(:,missing);
%     tStart = tStart(missing);
%     tEnd = tEnd(missing);
% end

%% Compute the PSD for each time slice
tic;

nDet = length(tStart);

if isempty(gcp('nocreate')); parpool('Processes'); end

% Console progress bar (size based on number of iterations)
progInc = max(1, floor(nDet/50)); % Progress monitor increment
barLength = min(nDet, 50);
bar = repmat('-', 1, barLength);

fprintf('')
fprintf('LTSA Started at: %s\n',datestr(now))
fprintf('Folder: %s\n',fileparts(fileInfo(1).fname));
fprintf('%g time chunks\n',nDet);
fprintf ('Progress (percent)\n');
fprintf('0|%s|100\n  ', bar);


% Create DataQueue and prepare progress display
D = parallel.pool.DataQueue;
afterEach(D, @(~) fprintf('#'));

parfor i = 1:nDet
    try
        avgStart = tStart(i);
        avgEnd = tEnd(i);%     [audNoise weighting] = getAudioFromFiles(fileInfo,avgStart,avgEnd);
        [audio, ~] = getAudioFromFiles(fileInfo, avgStart,avgEnd, ...
            exclusions=exclusions, channel=channel, newRate=sampleRate);
        
        if length(audio) < nfft
            continue
        end
        [ltsa(:,i),freqs] = pwelch(audio,nfft,noverlap,nfft,sampleRate);

        if rem(i,progInc)==0 
            send(D,i); % Console progress
        end

    catch
%         % If an error occurs, save the results to disk anyway
% %         save(saveFile,'t','freqs','ltsa','fileInfo','i','nfft','noverlap','numberOfAverages');
       keyboard
    end
end
% ltsa(:,missing) = t_ltsa;
% Write the PSD to a file
save(saveFile,'t','freqs','ltsa','-mat','-v7.3');
fprintf('\nDone at %s\n\n',datestr(now))

