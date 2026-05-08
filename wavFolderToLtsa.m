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
%   verbose           Print progress to console. Default: true.
%
% Outputs:
%   ltsa    numFreqs x numSlices matrix of PSD values (linear, not dB).
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
    options.verbose            (1,1) logical                            = true
end

doSave       = strlength(saveFile) > 0;
doClicks     = isfinite(options.clickThreshold);
doIncremental = options.saveIncrement ~= "none";

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
bytesNeeded = numel(freqs) * nSlices * 8;   % double = 8 bytes
if bytesNeeded > 4e9                        % warn above 4 GB
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
% Split into chunks if saveIncrement is set, otherwise run as one chunk
% -------------------------------------------------------------------------
if doIncremental
    chunkBounds = buildChunkBounds(t, options.saveIncrement, endTime, tInc);
else
    chunkBounds = [startTime, endTime];
end
nChunks = size(chunkBounds, 1);

% Pre-allocate full outputs (populated chunk by chunk)
ltsa     = nan(numel(freqs), nSlices);
errorLog = struct('sliceIdx', {}, 'time', {}, 'message', {}, 'expected', {});

% -------------------------------------------------------------------------
% Main loop over chunks
% -------------------------------------------------------------------------
for iChunk = 1:nChunks

    cStart  = chunkBounds(iChunk, 1);
    cEnd    = chunkBounds(iChunk, 2);
    cMask   = t >= cStart & t < cEnd;
    tChunk  = t(cMask);
    cIdx    = find(cMask);
    nC      = numel(tChunk);

    if nC == 0; continue; end

    ltsaChunk    = nan(numel(freqs), nC);
    errChunk     = struct('sliceIdx', {}, 'time', {}, 'message', {}, 'expected', {});

    barLen  = min(nC, 50);
    progIdx = unique(round(linspace(1, nC, barLen)));

    if options.verbose
        if doIncremental
            fprintf('\nChunk %d/%d  (%s to %s)\n', iChunk, nChunks, ...
                datestr(cStart, 'yyyy-mm-dd'), datestr(cEnd, 'yyyy-mm-dd'));
        end
        fprintf('Progress (%d slices)\n', nC);
        fprintf('0|%s|100\n  ', repmat('-', 1, barLen));
    end

    D = parallel.pool.DataQueue;
    if options.verbose
        afterEach(D, @(~) fprintf('#'));
    end

    % Slice start/end as vectors (avoids broadcasting t into parfor)
    tSliceStart = tChunk;
    tSliceEnd   = tChunk + tInc;

    if options.parallel
        % Ensure pool exists
        if isempty(gcp('nocreate'))
            parpool('Processes');
        end

        % parfor cannot assign to a struct array with dynamic fields, so
        % collect errors as cell array and convert after
        errCellMsg      = cell(nC, 1);
        errCellExpected = false(nC, 1);

        parfor iS = 1:nC
            [ltsaChunk(:,iS), errCellMsg{iS}, errCellExpected(iS)] = ...
                computeSlice(fileInfo, tSliceStart(iS), tSliceEnd(iS), ...
                    nfft, noverlap, sampleRate, ...
                    options.exclusions, options.channel, ...
                    doClicks, options.clickThreshold, options.clickAmount); %#ok<PFBNS>

            if any(progIdx == iS)
                send(D, iS);
            end
        end % parfor

        % Collect errors from parfor
        for iS = 1:nC
            if ~isempty(errCellMsg{iS})
                errChunk(end+1) = struct( ...
                    'sliceIdx', cIdx(iS), ...
                    'time',     tSliceStart(iS), ...
                    'message',  errCellMsg{iS}, ...
                    'expected', errCellExpected(iS)); %#ok<AGROW>
            end
        end

    else
        % Serial path
        for iS = 1:nC
            [ltsaChunk(:,iS), msg, isExpected] = ...
                computeSlice(fileInfo, tSliceStart(iS), tSliceEnd(iS), ...
                    nfft, noverlap, sampleRate, ...
                    options.exclusions, options.channel, ...
                    doClicks, options.clickThreshold, options.clickAmount);

            if ~isempty(msg)
                errChunk(end+1) = struct( ...
                    'sliceIdx', cIdx(iS), ...
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

    % Copy chunk into full arrays
    ltsa(:, cMask) = ltsaChunk;
    errorLog       = [errorLog, errChunk]; %#ok<AGROW>

    % Save this chunk if incremental
    if doSave && doIncremental
        chunkFile = makeChunkFilename(saveFile, cStart, options.saveIncrement);
        t_chunk   = tChunk;      %#ok<NASGU> % renamed to avoid shadowing t
        ltsa_chunk = ltsaChunk;  %#ok<NASGU>
        errorLog_chunk = errChunk; %#ok<NASGU>
        save(chunkFile, '-mat', '-v7.3', ...
            't_chunk', 'ltsa_chunk', 'freqs', 'errorLog_chunk');
        if options.verbose
            fprintf('  Saved: %s\n', chunkFile);
        end
    end

end % chunk loop

% -------------------------------------------------------------------------
% Final save (non-incremental)
% -------------------------------------------------------------------------
if doSave && ~doIncremental
    save(saveFile, 't', 'freqs', 'ltsa', 'errorLog', '-v7.3');
    if options.verbose
        fprintf('\nSaved: %s\n', saveFile);
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
        % Too short — data gap or duty-cycle boundary, expected
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
    isExpected = false;   % unexpected — caller will log with full message
end

end


% =========================================================================
%  Local: build chunk boundary matrix for incremental save
% =========================================================================
function bounds = buildChunkBounds(t, increment, endTime, tInc)
% Returns Nx2 datenum matrix of [chunkStart chunkEnd] pairs.

tDT  = datetime(t, 'ConvertFrom', 'datenum');
tEnd = datetime(endTime, 'ConvertFrom', 'datenum');

switch increment
    case "daily";   unit = 'day';
    case "monthly"; unit = 'month';
    case "yearly";  unit = 'year';
end

% Walk forward through calendar boundaries using dateshift
chunkStart = dateshift(tDT(1), 'start', unit);
finalEnd   = dateshift(tEnd,   'end',   unit);

allStarts = chunkStart;
cur = chunkStart;
while true
    cur = dateshift(cur + days(1), 'start', unit);
    if cur > finalEnd; break; end
    allStarts(end+1) = cur; %#ok<AGROW>
end
allEnds = [allStarts(2:end), finalEnd];

bounds = [datenum(allStarts(:)), datenum(allEnds(:))];
end


% =========================================================================
%  Local: construct chunk filename from saveFile stem and chunk start date
% =========================================================================
function chunkFile = makeChunkFilename(saveFile, chunkStart, increment)
[folder, stem, ~] = fileparts(saveFile);
dt = datetime(chunkStart, 'ConvertFrom', 'datenum');
switch increment
    case "daily";   suffix = datestr(dt, 'yyyy-mm-dd');
    case "monthly"; suffix = datestr(dt, 'yyyy-mm');
    case "yearly";  suffix = datestr(dt, 'yyyy');
end
chunkFile = fullfile(folder, sprintf('%s_%s.mat', stem, suffix));
end
