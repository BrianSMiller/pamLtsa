%% test_wavFolderToLtsa_sliceInterval.m
%
% Functional test for the sliceInterval option of wavFolderToLtsa.
%
% Computes 3 days of 1 h slices starting at 23:30, two ways:
%   A. contiguous (default sliceInterval), no chunking
%   B. sparse, one slice every 6 h, in daily chunks
% Every 6th slice of A should equal B exactly. Daily chunks exercise the
% slice that straddles midnight (23:30-00:30), which must be kept once.
%
% Data required (same as test_wavFolderToLtsa_250Hz_fullYear):
%   S:\work\250Hz\Kerguelen2015\   (250 Hz downsampled wav files)
%
% See also: wavFolderToLtsa, catLtsa

wavFolder = fullfile('S:\work\250Hz\Kerguelen2015\');
outDir    = fullfile(tempdir, 'test_sliceInterval');
if exist(outDir, 'dir'); rmdir(outDir, 's'); end
mkdir(outDir);

fprintf('=== test_wavFolderToLtsa_sliceInterval ===\n');
wavInfo = wavFolderInfo(wavFolder, 'yyyy-mm-dd_HH-MM-SS', false, false);

% Start at 23:30 on the first full day, run 3 days
day0      = floor(wavInfo(1).startDate) + 1;
startTime = day0 - 0.5/24;
endTime   = startTime + 3;

%% A: contiguous hourly slices, no chunking
[ltsaA, tA] = wavFolderToLtsa("", wavInfo, startTime, endTime, verbose = false);

%% B: sparse, 1 h every 6 h, daily chunks
stemB = fullfile(outDir, 'sparse');
[ltsaB, tB] = wavFolderToLtsa(stemB, wavInfo, startTime, endTime, ...
    sliceInterval = 6*3600, saveIncrement = "daily", verbose = false);

%% Test 1: slice times are every 6 h from startTime, none missing or doubled
fprintf('\nTest 1: slice times...\n');
expected = startTime + (0:11) * 6/24;
assert(numel(tB) == numel(expected), ...
    sprintf('Expected %d sparse slices, got %d', numel(expected), numel(tB)));
assert(max(abs(tB - expected)) * 86400 < 1, 'Sparse slice times off the 6 h grid');
fprintf('  PASS: %d slices, every 6 h from 23:30\n', numel(tB));

%% Test 2: sparse slices equal every 6th contiguous slice
fprintf('\nTest 2: sparse equals every 6th contiguous slice...\n');
[~, iA, iB] = intersect(round(tA * 86400), round(tB * 86400));
assert(numel(iB) == numel(tB), 'Some sparse slices have no contiguous match');
dB = 10*log10(ltsaB(2:end, iB)) - 10*log10(ltsaA(2:end, iA));
assert(max(abs(dB(:))) < 1e-6, ...
    sprintf('Sparse and contiguous differ by up to %.3g dB', max(abs(dB(:)))));
fprintf('  PASS: %d slices identical\n', numel(iB));

%% Test 3: sliceInterval shorter than durationOfAverage is an error
fprintf('\nTest 3: overlapping slices rejected...\n');
try
    wavFolderToLtsa("", wavInfo, startTime, endTime, ...
        sliceInterval = 1800, verbose = false);
    error('Expected an error for sliceInterval < durationOfAverage');
catch ME
    assert(strcmp(ME.identifier, 'wavFolderToLtsa:overlappingSlices'), ME.message);
end
fprintf('  PASS\n');

rmdir(outDir, 's');
fprintf('\n=== All tests passed ===\n');
