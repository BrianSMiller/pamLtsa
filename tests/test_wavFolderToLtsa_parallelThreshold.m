%% test_wavFolderToLtsa_parallelThreshold.m
%
% Empirically determines the optimal parallelThreshold for wavFolderToLtsa
% on this machine by measuring:
%   1. Pool startup cost
%   2. Serial rate (s/slice)
%   3. Wall time across a range of worker counts at fixed N
%   4. Break-even N — minimum slices where parallel beats serial
%
% Run once after any significant hardware change. The recommended
% parallelThreshold printed at the end can be passed as:
%   wavFolderToLtsa(..., parallelThreshold=N)
%
% See also: wavFolderToLtsa, snr_parallel_guide_casey2019

fprintf('=== wavFolderToLtsa parallel threshold benchmark  (%s) ===\n\n', datestr(now));

% -------------------------------------------------------------------------
%% CONFIGURE
% -------------------------------------------------------------------------
wavFolder = 'S:\work\250Hz\Kerguelen2014\';
addpath('c:\analysis\bsmUtils\');
addpath('c:\analysis\pamLtsa\');
addpath('c:\analysis\soundFolder\');

serialN  = 50;   % slices for serial baseline (keep short)
sweepN   = 200;  % slices for worker sweep (enough to amortise startup)
maxWorkers = feature('numcores') - 1;

% Fixed test window — edit if this period has gaps
testStart = datenum(2014, 4, 1, 0, 0, 0);

% -------------------------------------------------------------------------
%% SETUP
% -------------------------------------------------------------------------
fprintf('Building fileInfo...\n');
fileInfo = wavFolderInfo(wavFolder, 'yyyy-mm-dd_HH-MM-SS');

% Shared options for all timing runs
durationOfAverage = 3600;
freqResolution    = 1;
noverlap          = 0;

serialEnd = testStart + serialN/24;
sweepEnd  = testStart + sweepN/24;

% -------------------------------------------------------------------------
%% 1. Pool startup cost
% -------------------------------------------------------------------------
fprintf('--- 1. Pool startup cost ---\n');
if ~isempty(gcp('nocreate'))
    delete(gcp('nocreate'));
end
t0 = tic;
evalc('parpool(''Processes'', maxWorkers);');
tStartup = toc(t0);
fprintf('  parpool (%d workers): %.1f s\n\n', maxWorkers, tStartup);

% -------------------------------------------------------------------------
%% 2. Serial baseline
% -------------------------------------------------------------------------
fprintf('--- 2. Serial baseline (N=%d slices) ---\n', serialN);
delete(gcp('nocreate'));   % ensure no pool running

t0 = tic;
evalc('wavFolderToLtsa("", fileInfo, testStart, serialEnd, durationOfAverage=durationOfAverage, freqResolution=freqResolution, noverlap=noverlap, parallel=false, verbose=false);');
tSerial = toc(t0);
tPerSlice = tSerial / serialN;

fprintf('  %d slices in %.1f s  →  %.3f s/slice\n', serialN, tSerial, tPerSlice);
fprintf('  Estimated serial time for %d slices: %.1f s\n\n', sweepN, tPerSlice*sweepN);

% -------------------------------------------------------------------------
%% 3. Worker sweep
% -------------------------------------------------------------------------
nWorkersList = unique([1, 4, 8, 16, maxWorkers]);
nWorkersList = nWorkersList(nWorkersList <= maxWorkers);

fprintf('--- 3. Worker sweep (N=%d slices, workers=%s) ---\n', ...
    sweepN, mat2str(nWorkersList));

tByWorkers = nan(size(nWorkersList));

for k = 1:numel(nWorkersList)
    nW = nWorkersList(k);

    % Start pool at requested size
    if ~isempty(gcp('nocreate')); delete(gcp('nocreate')); end
    evalc(sprintf('parpool(''Processes'', %d);', nW));

    t0 = tic;
    evalc('wavFolderToLtsa("", fileInfo, testStart, sweepEnd, durationOfAverage=durationOfAverage, freqResolution=freqResolution, noverlap=noverlap, parallel=true, verbose=false);');
    tByWorkers(k) = toc(t0);

    fprintf('  %2d workers: %.1f s  (%.3f s/slice)\n', ...
        nW, tByWorkers(k), tByWorkers(k)/sweepN);
end

[tBest, bestIdx] = min(tByWorkers);
nBest = nWorkersList(bestIdx);
fprintf('\n  Fastest: %d workers  →  %.1f s\n\n', nBest, tBest);

% -------------------------------------------------------------------------
%% 4. Break-even N
% -------------------------------------------------------------------------
fprintf('--- 4. Break-even N ---\n');

tParPerSlice = tBest / sweepN;

if tPerSlice > tParPerSlice
    breakEven = ceil(tStartup / (tPerSlice - tParPerSlice));
    fprintf('  Serial rate:   %.3f s/slice\n', tPerSlice);
    fprintf('  Parallel rate: %.3f s/slice (%d workers)\n', tParPerSlice, nBest);
    fprintf('  Startup cost:  %.1f s\n', tStartup);
    fprintf('  Break-even:    %d slices\n', breakEven);
    fprintf('\n  Recommended parallelThreshold: %d\n\n', breakEven);
else
    breakEven = Inf;
    fprintf('  Parallel not faster than serial at N=%d — consider parallel=false\n\n', sweepN);
end

% -------------------------------------------------------------------------
%% 5. Plot
% -------------------------------------------------------------------------
figure('Name', 'wavFolderToLtsa parallel benchmark', ...
    'Units', 'centimeters', 'Position', [2 2 18 10]);

plot(nWorkersList, tByWorkers, 'o-', 'LineWidth', 1.5); hold on;
yline(tPerSlice * sweepN, '--', 'Serial', 'LabelHorizontalAlignment', 'left');
plot(nBest, tBest, 'r*', 'MarkerSize', 12);
xlabel('Number of workers');
ylabel(sprintf('Wall time (s)  [N=%d slices]', sweepN));
title('wavFolderToLtsa — worker sweep');
grid on;
legend('Parallel wall time', 'Serial equivalent', 'Fastest', ...
    'Location', 'northeast');

fprintf('Done.\n');
