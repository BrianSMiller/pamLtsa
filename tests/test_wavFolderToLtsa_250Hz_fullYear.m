%% test_wavFolderToLtsa_fullYear.m
%
% Basic functional test for wavFolderToLtsa on a full year of 250 Hz data.
%
% Verifies that:
%   1. wavFolderToLtsa completes without error on a full year
%   2. Output dimensions are consistent with input
%   3. Frequency vector is correct for 250 Hz at 1 Hz resolution
%   4. Time vector spans the expected range
%   5. LTSA contains finite values (data was read and processed)
%   6. Output .mat file is saved and loadable
%
% Also serves as a performance baseline -- expected runtime ~1 min on a
% 32-core machine with 250 Hz wav files on local SSD.
%
% Data required:
%   S:\work\250Hz\Kerguelen2015\   (250 Hz downsampled wav files)
%
% See also: wavFolderToLtsa, wavFolderInfo

%% Setup
wavFolder = fullfile('S:\work\250Hz\Kerguelen2015\');
saveFile  = fullfile(tempdir, 'test_wavFolderToLtsa_fullYear.mat');
if exist(saveFile, 'file'); delete(saveFile); end

fprintf('=== test_wavFolderToLtsa_fullYear ===\n');
fprintf('Loading wavFolderInfo...\n');
wavInfo = wavFolderInfo(wavFolder, 'yyyy-mm-dd_HH-MM-SS');

fprintf('Running wavFolderToLtsa (full year, 250 Hz)...\n');
tic
[ltsa, t, freqs] = wavFolderToLtsa(saveFile, wavInfo, ...
    wavInfo(1).startDate, wavInfo(end).endDate);
elapsed = toc;
fprintf('Completed in %.1f s\n', elapsed);

%% Test 1: output dimensions consistent
fprintf('\nTest 1: output dimensions...\n');
nSlices   = numel(t);
nFreqs    = numel(freqs);
assert(size(ltsa, 1) == nFreqs,  'ltsa rows != numel(freqs)');
assert(size(ltsa, 2) == nSlices, 'ltsa cols != numel(t)');
fprintf('  PASS: %d frequencies x %d slices\n', nFreqs, nSlices);

%% Test 2: frequency vector correct for 250 Hz at 1 Hz resolution
fprintf('\nTest 2: frequency vector...\n');
% At 250 Hz sample rate, nfft = nextpow2(250/1) = 256
% freqs should run 0:1:125 Hz (nfft/2 + 1 = 129 bins)
expectedNfft   = 2^nextpow2(250/1);  % 256
expectedNFreqs = expectedNfft/2 + 1; % 129
assert(nFreqs == expectedNFreqs, ...
    sprintf('Expected %d freq bins, got %d', expectedNFreqs, nFreqs));
assert(abs(freqs(end) - 125) < 1, ...
    sprintf('Expected max freq ~125 Hz, got %.1f', freqs(end)));
fprintf('  PASS: %d bins, max freq %.1f Hz\n', nFreqs, freqs(end));

%% Test 3: time vector spans expected range
fprintf('\nTest 3: time vector range...\n');
assert(t(1)   >= wavInfo(1).startDate,   't(1) before first wav file');
assert(t(end) <= wavInfo(end).endDate,    't(end) after last wav file');
durationDays = t(end) - t(1);
assert(durationDays > 300, ...
    sprintf('Expected > 300 days, got %.1f', durationDays));
fprintf('  PASS: %.1f days spanned\n', durationDays);

%% Test 4: LTSA contains finite values
fprintf('\nTest 4: finite values present...\n');
fracFinite = mean(isfinite(ltsa(:)));
assert(fracFinite > 0.5, ...
    sprintf('Expected >50%% finite values, got %.1f%%', fracFinite*100));
fprintf('  PASS: %.1f%% finite values\n', fracFinite*100);

%% Test 5: output file saved and loadable
fprintf('\nTest 5: output file saved and loadable...\n');
assert(exist(saveFile, 'file') == 2, 'Output .mat file not found');
s = load(saveFile, '-mat');
assert(isfield(s, 'ltsa'),     'ltsa missing from saved file');
assert(isfield(s, 't'),        't missing from saved file');
assert(isfield(s, 'freqs'),    'freqs missing from saved file');
assert(isfield(s, 'errorLog'), 'errorLog missing from saved file');
assert(isequal(s.t, t),        'saved t does not match returned t');
fprintf('  PASS: file saved and variables present\n');

%% Cleanup
delete(saveFile);

fprintf('\n=== All tests passed (%.1f s) ===\n\n', elapsed);
