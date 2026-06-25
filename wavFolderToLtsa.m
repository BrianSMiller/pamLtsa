function [ltsa, t, freqs] = wavFolderToLtsa(saveFile, fileInfo, startTime, endTime, options)
% wavFolderToLtsa  Compute a long-term spectral average from a wav folder.
%
% Given a soundFolder (output of wavFolderInfo), compute the LTSA by
% dividing the requested time range into fixed-duration slices and
% estimating the power spectral density of each slice using Welch's method.
%
% Usage:
%   [ltsa, t, freqs] = wavFolderToLtsa(saveFile, fileInfo, startTime, endTime)
%   [ltsa, t, freqs] = wavFolderToLtsa(saveFile, fileInfo, startTime, endTime, Name=Value, ...)
%   [ltsa, t, freqs] = wavFolderToLtsa("",       fileInfo, startTime, endTime, ...)
%
% Required inputs:
%   saveFile          Path to output .mat file. Pass "" or [] to skip saving.
%   fileInfo          Struct array from wavFolderInfo (or equivalent).
%   startTime         Start of LTSA time grid (MATLAB datenum).
%   endTime           End of LTSA time grid (MATLAB datenum).
%
% Optional name-value inputs:
%   durationOfAverage Duration of each LTSA slice in seconds. Default: 3600.
%   freqResolution    Frequency resolution in Hz. Determines nfft via
%                     nextpow2(sampleRate/freqResolution). Default: 1.
%   noverlap          FFT overlap in samples within each Welch estimate.
%                     Default: 0.
%   channel           Audio channel to use. Default: 1.
%   exclusions        Nx2 datenum array of [start end] exclusion periods.
%                     Default: [] (no exclusions).
%   parallel          Use parfor for slice computation. Default: true.
%   clickThreshold    Click suppression threshold in standard deviations.
%                     Set to Inf to disable. Default: Inf.
%   clickAmount       Click suppression replacement level. Default: 1000.
%   saveIncrement     Chunk output into separate files: "none", "daily",
%                     "monthly", or "yearly". Default: "none".
%                     When set, calls wavFolderToLtsa recursively once per
%                     chunk so each chunk gets full parallel throughput.
%                     Existing chunk files are skipped (incremental).
%                     Returns empty ltsa/t/freqs -- use catLtsa to combine.
%   rebuild           When saveIncrement ~= "none", re-compute chunks even
%                     if the output file already exists. Default: false.
%   verbose           Print progress to console. Default: true.
%
% Outputs:
%   ltsa    numFreqs x numSlices matrix of PSD values (linear, not dB).
%           Empty when saveIncrement ~= "none" (use catLtsa to combine).
%   t       1 x numSlices datenum vector (slice start times).
%   freqs   numFreqs x 1 frequency vector in Hz.
%
% Errors encountered during processing are logged and saved alongside the
% LTSA in the output .mat file as the variable 'errorLog'.
%
% See also: wavFolderInfo, getAudioFromFiles, pwelch, removeClicks, catLtsa

% -------------------------------------------------------------------------
% Input handling
% -------------------------------------------------------------------------
arguments
    saveFile           (1,1) string
    fileInfo           (1,:) struct
    startTime          (1,1) double
    endTime            (1,1) double
    options.durationOfAverage  (1,1) double  {mustBePositive}           = 3600
    options.freqResolution     (1,1) double  {mustBePositive}           = 1
    options.noverlap           (1,1) double  {mustBeNonnegative}        = 0
    options.channel            (1,1) double  {mustBePositive, mustBeInteger} = 1
    options.exclusions         (:,2) double                             = zeros(0,2)
    options.parallel           (1,1) logical                            = true
    options.clickThreshold     (1,1) double  {mustBePositive}           = Inf
    options.clickAmount        (1,1) double  {mustBePositive}           = 1000
    options.saveIncrement      (1,1) string  {mustBeMember(options.saveIncrement, ...
                                   ["none","daily","monthly","yearly"])} = "none"
    options.rebuild            (1,1) logical                            = false
    options.verbose            (1,1) logical                            = true
end

doSave   = strlength(saveFile) > 0;
doClicks = isfinite(options.clickThreshold);

% -------------------------------------------------------------------------
% saveIncrement: work out chunks and filenames, call wavFolderToLtsa each
% -------------------------------------------------------------------------
if options.saveIncrement ~= "none"
    tInc        = options.durationOfAverage / 86400;
    chunkBounds = buildChunkBounds(startTime, options.saveIncrement, endTime, tInc);
    nChunks     = size(chunkBounds, 1);
    nfft        = 2 ^ nextpow2(fileInfo(1).sampleRate / options.freqResolution);
    [~, freqs]  = pwelch(zeros(nfft, 1), nfft, options.noverlap, ...
                         nfft, fileInfo(1).sampleRate);
    ltsa = []; t = [];
    if options.verbose
        fprintf('wavFolderToLtsa: %d %s chunks\n', nChunks, options.saveIncrement);
    end
    for iChunk = 1:nChunks
        cStart    = chunkBounds(iChunk, 1);
        cEnd      = chunkBounds(iChunk, 2);
        chunkFile = makeChunkFilename(saveFile, cStart, options.saveIncrement);
        if exist(chunkFile, 'file') && ~options.rebuild
            if options.verbose
                fprintf('  Skipping: %s\n', chunkFile);
            end
            continue
        end
        if options.verbose
            fprintf('  Chunk %d/%d: %s\n', iChunk, nChunks, ...
                datestr(cStart, 'yyyy-mm-dd'));
        end
        wavFolderToLtsa(chunkFile, fileInfo, cStart, cEnd, ...
            durationOfAverage = options.durationOfAverage, ...
            freqResolution    = options.freqResolution, ...
            noverlap          = options.noverlap, ...
            channel           = options.channel, ...
            exclusions        = options.exclusions, ...
            parallel          = options.parallel, ...
            clickThreshold    = options.clickThreshold, ...
            clickAmount       = options.clickAmount, ...
            verbose           = options.verbose);
    end
    
    % Combine and return via catLtsa
    [ltsa, t, freqs] = catLtsa(saveFile, ...
        durationOfAverage = options.durationOfAverage, ...
        verbose           = false);
    return
end

% -------------------------------------------------------------------------
% Derived FFT parameters
% -------------------------------------------------------------------------
sampleRate = fileInfo(1).sampleRate;
nfft       = 2 ^ nextpow2(sampleRate / options.freqResolution);
noverlap   = options.noverlap;

% Frequency vector (derived once from a dummy pwelch call)
[~, freqs] = pwelch(zeros(nfft, 1), nfft, noverlap, nfft, sampleRate);

% -------------------------------------------------------------------------
% Build time grid
% -------------------------------------------------------------------------
tInc = options.durationOfAverage / 86400;   % seconds -> days
t    = startTime : tInc : endTime;
t    = t(1:end-1);                          % slice start times
nSlices = numel(t);

if nSlices == 0
    warning('wavFolderToLtsa:emptyTimeRange', ...
        'No slices in requested time range. Check startTime/endTime.');
    ltsa = zeros(numel(freqs), 0);
    return
end

% -------------------------------------------------------------------------
% Memory preflight
% -------------------------------------------------------------------------
bytesNeeded = numel(freqs) * nSlices * 8;
if bytesNeeded > 4e9
    neededGB = bytesNeeded / 1e9;
    try
        mem    = memory;
        freeGB = mem.MemAvailableAllArrays / 1e9;
        if neededGB > freeGB * 0.8
            warning('wavFolderToLtsa:lowMemory', ...
                ['LTSA will require ~%.1f GB but only ~%.1f GB appears ' ...
                 'available. Consider using saveIncrement to chunk output.'], ...
                neededGB, freeGB);
        end
    catch
        warning('wavFolderToLtsa:memoryCheckFailed', ...
            'LTSA will require ~%.1f GB. Verify sufficient memory is available.', ...
            neededGB);
    end
end

% -------------------------------------------------------------------------
% Allocate outputs
% -------------------------------------------------------------------------
ltsa     = nan(numel(freqs), nSlices);
errorLog = struct('sliceIdx', {}, 'time', {}, 'message', {}, 'expected', {});

% -------------------------------------------------------------------------
% Progress bar
% -------------------------------------------------------------------------
barLen  = min(nSlices, 50);
progIdx = unique(round(linspace(1, nSlices, barLen)));

if options.verbose
    fprintf('Progress (%d slices)\n', nSlices);
    fprintf('0|%s|100\n  ', repmat('-', 1, barLen));
end

D = parallel.pool.DataQueue;
if options.verbose
    afterEach(D, @(~) fprintf('#'));
end

% -------------------------------------------------------------------------
% Slice start/end vectors
% -------------------------------------------------------------------------
tSliceStart = t;
tSliceEnd   = t + tInc;

% -------------------------------------------------------------------------
% Compute slices
% -------------------------------------------------------------------------
if options.parallel
    if isempty(gcp('nocreate'))
        parpool('Threads');
    end

    errCellMsg      = cell(nSlices, 1);
    errCellExpected = false(nSlices, 1);

    parfor iS = 1:nSlices
        [ltsa(:,iS), errCellMsg{iS}, errCellExpected(iS)] = ...
            computeSlice(fileInfo, tSliceStart(iS), tSliceEnd(iS), ...
                nfft, noverlap, sampleRate, ...
                options.exclusions, options.channel, ...
                doClicks, options.clickThreshold, options.clickAmount); %#ok<PFBNS>

        if any(progIdx == iS)
            send(D, iS);
        end
    end

    for iS = 1:nSlices
        if ~isempty(errCellMsg{iS})
            errorLog(end+1) = struct( ...
                'sliceIdx', iS, ...
                'time',     tSliceStart(iS), ...
                'message',  errCellMsg{iS}, ...
                'expected', errCellExpected(iS)); %#ok<AGROW>
        end
    end

else
    for iS = 1:nSlices
        [ltsa(:,iS), msg, isExpected] = ...
            computeSlice(fileInfo, tSliceStart(iS), tSliceEnd(iS), ...
                nfft, noverlap, sampleRate, ...
                options.exclusions, options.channel, ...
                doClicks, options.clickThreshold, options.clickAmount);

        if ~isempty(msg)
            errorLog(end+1) = struct( ...
                'sliceIdx', iS, ...
                'time',     tSliceStart(iS), ...
                'message',  msg, ...
                'expected', isExpected); %#ok<AGROW>
        end

        if any(progIdx == iS)
            send(D, iS);
        end
    end
end

if options.verbose; fprintf('\n'); end

% -------------------------------------------------------------------------
% Save
% -------------------------------------------------------------------------
if doSave
    save(saveFile, 't', 'freqs', 'ltsa', 'errorLog', '-v7.3');
    if options.verbose
        fprintf('Saved: %s\n', saveFile);
    end
end

if options.verbose
    nErr      = numel(errorLog);
    nExpected = sum([errorLog.expected]);
    fprintf('Done at %s  |  %d slices  |  %d skipped (%d unexpected)\n\n', ...
        datestr(now), nSlices, nErr, nErr - nExpected);
end

end % main function


% =========================================================================
%  Local: compute one LTSA slice
% =========================================================================
function [psd, errMsg, isExpected] = computeSlice( ...
        fileInfo, tStart, tEnd, nfft, noverlap, sampleRate, ...
        exclusions, channel, doClicks, clickThreshold, clickAmount)

psd        = nan(nfft/2 + 1, 1);
errMsg     = '';
isExpected = false;

try
    [audio, ~] = getAudioFromFiles(fileInfo, tStart, tEnd, ...
        exclusions=exclusions, channel=channel, newRate=sampleRate);

    if numel(audio) < nfft
        errMsg     = sprintf('audio too short (%d samples, need %d)', numel(audio), nfft);
        isExpected = true;
        return
    end

    if doClicks
        audio = removeClicks(audio, clickThreshold, clickAmount);
    end

    [psd, ~] = pwelch(audio, nfft, noverlap, nfft, sampleRate);

catch ME
    errMsg     = ME.message;
    isExpected = false;
end

end


% =========================================================================
%  Local: build chunk boundary matrix
% =========================================================================
function bounds = buildChunkBounds(startTime, increment, endTime, tInc)
tDT  = datetime(startTime, 'ConvertFrom', 'datenum');
tEnd = datetime(endTime,   'ConvertFrom', 'datenum');

switch increment
    case "daily"
        allStarts = dateshift(tDT : caldays(1)   : tEnd, 'start', 'day');
        unit = 'day';
    case "monthly"
        allStarts = dateshift(tDT : calmonths(1) : tEnd, 'start', 'month');
        unit = 'month';
    case "yearly"
        allStarts = dateshift(tDT : calyears(1)  : tEnd, 'start', 'year');
        unit = 'year';
end
allStarts = unique(allStarts);
allEnds   = [allStarts(2:end), dateshift(tEnd, 'end', unit)];

bounds = [datenum(allStarts(:)), datenum(allEnds(:))];
end
