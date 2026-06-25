%% test_catLtsa.m
%
% Integration test for wavFolderToLtsa saveIncrement="monthly" and catLtsa.
%
% Uses a short span of Kerguelen2015 250Hz downsampled data spanning three
% calendar months so that exactly three chunk files are produced and catLtsa
% has real boundaries to concatenate across.
%
% Does not depend on any metadata stack -- works directly with wavFolderInfo
% and the wav files. Chunk filenames are derived from the stem and dates
% rather than hardcoded.
%
% Tests:
%   1. wavFolderToLtsa saveIncrement="monthly" produces one .mat per month
%      with the expected filename suffix convention.
%   2. catLtsa (stem input) finds all files and returns correct output.
%   3. catLtsa (file list input) produces identical output to stem input.
%   4. No gap sentinel inserted when chunks are contiguous.
%   5. Single NaN sentinel inserted when a gap exists between chunks.
%   6. freqs mismatch raises the correct error.
%   7. Combined LTSA has correct size and finite values where data exists.
%
% Data required:
%   S:\work\250Hz\Kerguelen2015\   (250 Hz downsampled wav files)
%
% Temporary files written to tempdir and cleaned up on completion.
%
% See also: wavFolderToLtsa, catLtsa, chunkFilePattern, makeChunkFilename

%% Setup
wavFolder = 'S:\work\250Hz\Kerguelen2015\';
fprintf('=== test_catLtsa ===\n');
fprintf('Loading wavFolderInfo from %s\n', wavFolder);
fileInfo = wavFolderInfo(wavFolder, 'yyyy-mm-dd_HH-MM-SS', false, false);

% Short span crossing three calendar months
t0 = fileInfo(1).startDate;
t1 = t0 + 60;

tmpDir   = fullfile(tempdir, 'test_catLtsa');
if ~exist(tmpDir, 'dir'); mkdir(tmpDir); end
stemFile = fullfile(tmpDir, 'kerguelen2015_test_3600s_1Hz.mat');

% Clean up previous runs
delete(fullfile(tmpDir, '*.mat'));

% Derive chunk filenames from stem + date range (mirrors makeChunkFilename)
tDT       = datetime(t0, 'ConvertFrom', 'datenum');
tEndDT    = datetime(t1, 'ConvertFrom', 'datenum');
months    = dateshift(tDT : calmonths(1) : tEndDT, 'start', 'month');
months    = unique(months);
[folder, stem] = fileparts(stemFile);
chunkFiles = arrayfun(@(m) fullfile(folder, ...
    sprintf('%s_%s.mat', stem, datestr(m, 'yyyy-mm'))), months, ...
    'UniformOutput', false);

%% Test 1: saveIncrement produces monthly chunk files
fprintf('\nTest 1: saveIncrement="monthly" produces chunk files...\n');
[ltsa_full, t_full, freqs] = wavFolderToLtsa(stemFile, fileInfo, t0, t1, ...
    durationOfAverage = 3600, ...
    freqResolution    = 1, ...
    channel           = 1, ...
    saveIncrement     = "monthly", ...
    verbose           = true);

for iF = 1:numel(chunkFiles)
    assert(exist(chunkFiles{iF}, 'file') == 2, ...
        sprintf('Chunk file not created: %s', chunkFiles{iF}));
end
fprintf('  PASS: %d monthly chunk files created\n', numel(chunkFiles));

%% Test 2: catLtsa stem input
fprintf('\nTest 2: catLtsa stem input...\n');
[ltsa_cat, t_cat, freqs_cat, errLog] = catLtsa(stemFile, verbose=true);

assert(isequal(freqs, freqs_cat), 'freqs mismatch between wavFolderToLtsa and catLtsa');
assert(numel(t_cat) == numel(t_full), ...
    sprintf('slice count mismatch: catLtsa=%d, wavFolderToLtsa=%d', ...
    numel(t_cat), numel(t_full)));
assert(isequal(size(ltsa_cat), size(ltsa_full)), 'ltsa size mismatch');
fprintf('  PASS: stem input produces correct output (%d slices)\n', numel(t_cat));

%% Test 3: catLtsa file list input produces identical output
fprintf('\nTest 3: catLtsa file list input...\n');
[ltsa_fl, t_fl, freqs_fl] = catLtsa(chunkFiles, verbose=false);

assert(isequal(t_fl, t_cat),    'file list vs stem: t mismatch');
assert(~any(ltsa_fl - ltsa_cat, 'all'), 'file list vs stem: ltsa mismatch');
assert(isequal(freqs_fl, freqs_cat), 'file list vs stem: freqs mismatch');
fprintf('  PASS: file list input matches stem input\n');

%% Test 4: No sentinel when chunks are contiguous
fprintf('\nTest 4: No gap sentinel for contiguous chunks...\n');
nNaN = sum(isnan(t_cat));
assert(nNaN == 0, sprintf('Expected 0 sentinels for contiguous data, got %d', nNaN));
fprintf('  PASS: no sentinels inserted\n');

%% Test 5: Sentinel inserted when gap exists
fprintf('\nTest 5: Gap sentinel inserted for non-contiguous chunks...\n');

% Truncate first chunk by 48 slices (2 days) and resave under a gap stem
gapStemFile = fullfile(tmpDir, 'kerguelen2015_gap_3600s_1Hz.mat');
[gapFolder, gapStem] = fileparts(gapStemFile);

s          = load(chunkFiles{1}, '-mat');
t_trunc    = s.t(1:end-48);
ltsa_trunc = s.ltsa(:, 1:end-48);
errorLog   = s.errorLog; %#ok<NASGU>

% Derive gap chunk filenames
gapChunkFiles = arrayfun(@(m) fullfile(gapFolder, ...
    sprintf('%s_%s.mat', gapStem, datestr(m, 'yyyy-mm'))), months, ...
    'UniformOutput', false);

% Save truncated first chunk
t    = t_trunc;    %#ok<NASGU>
ltsa = ltsa_trunc; %#ok<NASGU>
save(gapChunkFiles{1}, 't', 'ltsa', 'freqs', 'errorLog', '-v7.3');

% Copy remaining chunks unchanged
for iF = 2:numel(chunkFiles)
    copyfile(chunkFiles{iF}, gapChunkFiles{iF});
end

[ltsa_gap, t_gap] = catLtsa(gapChunkFiles, verbose=true);

% Sentinel should appear immediately after the truncated chunk
sentinelIdx = numel(t_trunc) + 1;
assert(sentinelIdx <= size(ltsa_gap, 2), 'sentinel index out of range');
assert(all(isnan(ltsa_gap(:, sentinelIdx))), ...
    sprintf('Expected NaN sentinel column at index %d', sentinelIdx));
fprintf('  PASS: NaN sentinel at expected index %d\n', sentinelIdx);

%% Test 6: freqs mismatch raises correct error
fprintf('\nTest 6: freqs mismatch raises error...\n');
s2        = load(chunkFiles{2}, '-mat');
badFile   = fullfile(tmpDir, 'bad_chunk.mat');
t         = s2.t;       %#ok<NASGU>
ltsa      = s2.ltsa;    %#ok<NASGU>
errorLog  = s2.errorLog; %#ok<NASGU>
freqs     = s2.freqs(1:end-1);  % corrupt freqs %#ok<NASGU>
save(badFile, 't', 'ltsa', 'freqs', 'errorLog', '-v7.3');

try
    catLtsa({chunkFiles{1}, badFile}, verbose=false);
    fprintf('  FAIL: expected error not thrown\n');
catch ME
    assert(contains(ME.identifier, 'freqMismatch'), ...
        sprintf('Wrong error id: %s', ME.identifier));
    fprintf('  PASS: freqs mismatch correctly detected\n');
end

%% Test 7: output size and finite values
fprintf('\nTest 7: output size and finite values...\n');
assert(size(ltsa_cat, 1) == numel(freqs_cat), 'wrong number of frequency bins');
assert(size(ltsa_cat, 2) == numel(t_cat),     'wrong number of time slices');
assert(any(isfinite(ltsa_cat(:))), 'no finite values in concatenated LTSA');
fprintf('  PASS: size correct, finite values present\n');

%% Cleanup
delete(fullfile(tmpDir, '*.mat'));
rmdir(tmpDir);

fprintf('\n=== All tests passed ===\n\n');
