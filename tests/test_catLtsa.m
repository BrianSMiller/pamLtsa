%% test_catLtsa.m
%
% Integration test for wavFolderToLtsa saveIncrement="monthly" and catLtsa.
%
% Uses a short span of Kerguelen2019 250Hz downsampled data spanning two
% calendar months (late January to early February) so that exactly two
% chunk files are produced and catLtsa has a real boundary to concatenate.
%
% Does not depend on metaDataKerguelen2019 or any metadata stack --
% works directly with wavFolderInfo and the wav files.
%
% Tests:
%   1. wavFolderToLtsa saveIncrement="monthly" produces one .mat per month
%      with the expected filename suffix convention.
%   2. catLtsa (stem input) finds both files and returns correct output.
%   3. catLtsa (file list input) produces identical output to stem input.
%   4. No gap sentinel inserted when chunks are contiguous.
%   5. Single NaN sentinel inserted when a gap exists between chunks.
%   6. freqs mismatch raises the correct error.
%   7. Combined LTSA has correct size and finite values where data exists.
%
% Data required:
%   S:\work\250Hz\Kerguelen2019\   (250 Hz downsampled wav files)
%
% Temporary files written to tempdir and cleaned up on completion.
%
% See also: wavFolderToLtsa, catLtsa, chunkFilePattern, makeChunkFilename

%% Setup
wavFolder = 'S:\work\250Hz\Kerguelen2019\';
fprintf('=== test_catLtsa ===\n');
fprintf('Loading wavFolderInfo from %s\n', wavFolder);
fileInfo = wavFolderInfo(wavFolder, [], false, false);

% Short span crossing Jan/Feb boundary
t0 = datenum([2019 01 28 00 00 00]);
t1 = datenum([2019 02 04 00 00 00]);

tmpDir   = fullfile(tempdir, 'test_catLtsa');
if ~exist(tmpDir, 'dir'); mkdir(tmpDir); end
stemFile = fullfile(tmpDir, 'kerguelen2019_test_3600s_1Hz.mat');

% Clean up previous runs
delete(fullfile(tmpDir, '*.mat'));

%% Test 1: saveIncrement produces monthly chunk files
fprintf('\nTest 1: saveIncrement="monthly" produces chunk files...\n');
[ltsa_full, t_full, freqs] = wavFolderToLtsa(stemFile, fileInfo, t0, t1, ...
    durationOfAverage = 3600, ...
    freqResolution    = 1, ...
    channel           = 1, ...
    saveIncrement     = "monthly", ...
    verbose           = true);

janFile = fullfile(tmpDir, 'kerguelen2019_test_3600s_1Hz_2019-01.mat');
febFile = fullfile(tmpDir, 'kerguelen2019_test_3600s_1Hz_2019-02.mat');

assert(exist(janFile, 'file') == 2, 'January chunk file not created');
assert(exist(febFile, 'file') == 2, 'February chunk file not created');
fprintf('  PASS: both monthly chunk files created\n');

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
[ltsa_fl, t_fl, freqs_fl] = catLtsa({janFile, febFile}, verbose=false);

assert(isequal(t_fl, t_cat),    'file list vs stem: t mismatch');
assert(isequal(ltsa_fl, ltsa_cat), 'file list vs stem: ltsa mismatch');
assert(isequal(freqs_fl, freqs_cat), 'file list vs stem: freqs mismatch');
fprintf('  PASS: file list input matches stem input\n');

%% Test 4: No sentinel when chunks are contiguous
fprintf('\nTest 4: No gap sentinel for contiguous chunks...\n');
nNaN = sum(isnan(t_cat));
assert(nNaN == 0, sprintf('Expected 0 sentinels for contiguous data, got %d', nNaN));
fprintf('  PASS: no sentinels inserted\n');

%% Test 5: Sentinel inserted when gap exists
fprintf('\nTest 5: Gap sentinel inserted for non-contiguous chunks...\n');

% Truncate jan chunk by 48 slices (2 days) and resave under a new stem
s = load(janFile, '-mat');
t_chunk        = s.t_chunk(1:end-48);       %#ok<NASGU>
ltsa_chunk     = s.ltsa_chunk(:, 1:end-48); %#ok<NASGU>
errorLog_chunk = s.errorLog_chunk;           %#ok<NASGU>

gapJanFile = fullfile(tmpDir, 'kerguelen2019_gap_3600s_1Hz_2019-01.mat');
save(gapJanFile, 't_chunk', 'ltsa_chunk', 'freqs', 'errorLog_chunk', '-v7.3');

gapFebFile = fullfile(tmpDir, 'kerguelen2019_gap_3600s_1Hz_2019-02.mat');
copyfile(febFile, gapFebFile);

[~, t_gap] = catLtsa({gapJanFile, gapFebFile}, verbose=true);
nNaN_gap = sum(isnan(t_gap));
assert(nNaN_gap == 1, sprintf('Expected 1 sentinel, got %d', nNaN_gap));
fprintf('  PASS: 1 gap sentinel inserted\n');

%% Test 6: freqs mismatch raises correct error
fprintf('\nTest 6: freqs mismatch raises error...\n');
s2 = load(febFile, '-mat');
freqs          = s2.freqs(1:end-1);   % corrupt freqs  %#ok<NASGU>
t_chunk        = s2.t_chunk;          %#ok<NASGU>
ltsa_chunk     = s2.ltsa_chunk;       %#ok<NASGU>
errorLog_chunk = s2.errorLog_chunk;   %#ok<NASGU>
badFile = fullfile(tmpDir, 'bad_2019-02.mat');
save(badFile, 't_chunk', 'ltsa_chunk', 'freqs', 'errorLog_chunk', '-v7.3');

try
    catLtsa({janFile, badFile}, verbose=false);
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
% At least some values should be finite (real data present)
assert(any(isfinite(ltsa_cat(:))), 'no finite values in concatenated LTSA');
fprintf('  PASS: size correct, finite values present\n');

%% Cleanup
delete(fullfile(tmpDir, '*.mat'));
rmdir(tmpDir);

fprintf('\n=== All tests passed ===\n\n');
