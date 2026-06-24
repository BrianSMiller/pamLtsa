function [ltsa, t, freqs, errorLog] = catLtsa(source, options)
% catLtsa  Concatenate chunked LTSA files produced by wavFolderToLtsa.
%
% Loads monthly (or daily/yearly) LTSA chunks saved by wavFolderToLtsa
% with saveIncrement ~= "none", sorts them chronologically, and
% concatenates into a single LTSA matrix. A single NaN sentinel column is
% inserted at each time gap boundary to prevent pcolor/surf from
% interpolating across gaps.
%
% Usage:
%   [ltsa, t, freqs, errorLog] = catLtsa(files)
%   [ltsa, t, freqs, errorLog] = catLtsa(stemPath)
%   [ltsa, t, freqs, errorLog] = catLtsa(__, Name=Value)
%
% Inputs:
%   files     Cell array of .mat chunk file paths (sorted automatically)
%   stemPath  String stem, e.g.:
%               "S:\ltsa\kerguelen2025_ALTO_ch1_3600s_1Hz"
%             Globs for stemPath_yyyy-mm.mat, stemPath_yyyy-mm-dd.mat,
%             and stemPath_yyyy.mat automatically.
%
% Optional name-value inputs:
%   saveFile          Path to save combined output .mat. Default: "" (no save)
%   gapSentinel       Insert a single NaN column at each gap boundary to
%                     prevent pcolor/surf interpolating across gaps.
%                     Sentinel time = last valid slice + durationOfAverage.
%                     Default: true
%   durationOfAverage Slice duration in seconds. Used to detect gaps and
%                     place sentinel timestamps. Default: inferred from
%                     median(diff(t)) of first chunk.
%   verbose           Print progress. Default: true
%
% Outputs:
%   ltsa      numFreqs x numSlices matrix (NaN sentinel columns at gaps)
%   t         1 x numSlices datenum vector (NaN at sentinel positions)
%   freqs     numFreqs x 1 frequency vector in Hz
%   errorLog  Combined error log struct array from all chunks
%
% See also: wavFolderToLtsa, loadLtsa, plotCalibratedLtsa

arguments
    source                        % string stem or cell array of files
    options.saveFile          (1,1) string  = ""
    options.gapSentinel       (1,1) logical = true
    options.durationOfAverage (1,1) double  = NaN   % inferred if NaN
    options.verbose           (1,1) logical = true
end

% -------------------------------------------------------------------------
% Resolve file list
% -------------------------------------------------------------------------
if ischar(source) || (isstring(source) && isscalar(source))
    files = globChunkFiles(string(source));
    if isempty(files)
        error('catLtsa:noFiles', 'No chunk files found matching stem: %s', source);
    end
elseif iscell(source)
    files = string(source(:));
else
    error('catLtsa:badInput', ...
        'source must be a stem string or cell array of file paths');
end

nFiles = numel(files);
if options.verbose
    fprintf('catLtsa: found %d chunk files\n', nFiles);
end

% -------------------------------------------------------------------------
% Load and sort chunks by their first timestamp
% -------------------------------------------------------------------------
chunks = struct('file', {}, 'tFirst', {}, 'ltsa', {}, 't', {}, ...
                'freqs', {}, 'errorLog', {});

for iF = 1:nFiles
    f = files(iF);
    if options.verbose
        fprintf('  Loading: %s\n', f);
    end
    s = load(f, '-mat');

    % Support both chunk variable names and full-file variable names
    if isfield(s, 't_chunk')
        tc   = s.t_chunk;
        lc   = s.ltsa_chunk;
        el   = s.errorLog_chunk;
    elseif isfield(s, 't')
        tc   = s.t;
        lc   = s.ltsa;
        el   = s.errorLog;
    else
        warning('catLtsa:unknownFormat', ...
            'Unrecognised variable names in %s — skipping', f);
        continue
    end

    chunks(end+1) = struct( ...
        'file',     f, ...
        'tFirst',   tc(1), ...
        'ltsa',     lc, ...
        't',        tc, ...
        'freqs',    s.freqs, ...
        'errorLog', el); %#ok<AGROW>
end

if isempty(chunks)
    error('catLtsa:noValidChunks', 'No valid chunk files could be loaded.');
end

% Sort by first timestamp
[~, ord] = sort([chunks.tFirst]);
chunks   = chunks(ord);

% -------------------------------------------------------------------------
% Validate freqs consistency across chunks
% -------------------------------------------------------------------------
freqs = chunks(1).freqs;
for iF = 2:numel(chunks)
    if ~isequal(freqs, chunks(iF).freqs)
        error('catLtsa:freqMismatch', ...
            'Frequency vector mismatch between %s and %s', ...
            chunks(1).file, chunks(iF).file);
    end
end

% -------------------------------------------------------------------------
% Infer durationOfAverage if not supplied
% -------------------------------------------------------------------------
tInc_days = options.durationOfAverage / 86400;
if isnan(options.durationOfAverage)
    % Infer from median slice spacing in first chunk
    if numel(chunks(1).t) > 1
        tInc_days = median(diff(chunks(1).t));
    else
        warning('catLtsa:cannotInferDuration', ...
            'Cannot infer durationOfAverage from single-slice chunk. ' ...
            'Supply durationOfAverage explicitly.');
        tInc_days = 1/24;  % fallback: 1 hour
    end
    if options.verbose
        fprintf('  Inferred durationOfAverage: %.0f s\n', tInc_days * 86400);
    end
end

% -------------------------------------------------------------------------
% Concatenate with gap sentinels
% -------------------------------------------------------------------------
nFreqs   = numel(freqs);
errorLog = struct('sliceIdx', {}, 'time', {}, 'message', {}, 'expected', {});

ltsa_parts = {};
t_parts    = {};

for iF = 1:numel(chunks)
    c = chunks(iF);

    % Check for gap between previous chunk and this one
    if iF > 1 && options.gapSentinel
        tPrevEnd  = t_parts{end}(end);
        tExpected = tPrevEnd + tInc_days;
        tThisStart = c.t(1);

        if tThisStart > tExpected + tInc_days * 0.5
            % Gap detected -- insert sentinel
            t_sentinel    = tPrevEnd + tInc_days;  % one slice after last valid
            ltsa_sentinel = nan(nFreqs, 1);
            t_parts{end+1}    = t_sentinel;     %#ok<AGROW>
            ltsa_parts{end+1} = ltsa_sentinel;  %#ok<AGROW>
            if options.verbose
                fprintf('  Gap detected before %s — sentinel inserted at %s\n', ...
                    datestr(tThisStart, 'yyyy-mm-dd'), ...
                    datestr(t_sentinel, 'yyyy-mm-dd HH:MM'));
            end
        end
    end

    t_parts{end+1}    = c.t(:)';        %#ok<AGROW>
    ltsa_parts{end+1} = c.ltsa;         %#ok<AGROW>

    % Accumulate error log with adjusted slice indices
    for iE = 1:numel(c.errorLog)
        errorLog(end+1) = c.errorLog(iE); %#ok<AGROW>
    end
end

ltsa = [ltsa_parts{:}];
t    = [t_parts{:}];

if options.verbose
    nSentinels = sum(isnan(t));
    fprintf('catLtsa: %d slices total (%d gap sentinels)\n', ...
        numel(t), nSentinels);
end

% -------------------------------------------------------------------------
% Optional save
% -------------------------------------------------------------------------
if strlength(options.saveFile) > 0
    save(options.saveFile, 't', 'freqs', 'ltsa', 'errorLog', '-v7.3');
    if options.verbose
        fprintf('Saved: %s\n', options.saveFile);
    end
end

end % main


% =========================================================================
%  Local: glob for chunk files matching a stem
% =========================================================================
function files = globChunkFiles(stem)
% Uses chunkFilePattern (private) to keep glob patterns in sync with
% makeChunkFilename conventions.

patterns = chunkFilePattern(stem, "any");

files = string.empty;
for iP = 1:numel(patterns)
    d = dir(patterns(iP));
    if ~isempty(d)
        found = fullfile(string({d.folder}'), string({d.name}'));
        files = [files; found]; %#ok<AGROW>
    end
end

% Sort alphabetically (ISO date suffixes sort correctly)
files = unique(sort(files));
end
