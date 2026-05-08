%% xwavToWav.m
%
% Convert ARP xwav files to standard wav files with timestamp filenames,
% then validate the conversion by comparing xwavFolderInfo against
% wavFolderInfo results.
%
% Each xwav file contains ~7 days of continuous audio. This script writes
% each xwav as a single wav file named yyyy-mm-dd_HH-MM-SS.wav, consistent
% with the naming convention used by all modern AAD MAR deployments.
% Already-converted files are skipped automatically — safe to re-run.
%
% NOTE: Hard-coded for single-channel recordings. All AAD ARP deployments
% are single-channel. For multi-channel HARPs, audioread/audiowrite calls
% would need updating.
%
% Usage:
%   Set dryRun = true  to preview what would be written without writing.
%   Set dryRun = false to perform the conversion and validate.
%
%   For parallel conversion, start a pool first:
%     parpool('Processes', 8);
%     xwavToWav
%
% Deployments covered:
%   Casey 2004      W:\LongTermRecording2002_present\ARPS\Casey04\xwav\
%   Kerguelen 2005  W:\LongTermRecording2002_present\ARPS\Kerguelen05\xwav\
%   Kerguelen 2006  W:\LongTermRecording2002_present\ARPS\Kerguelen06\xwav\
%   Prydz 2005      W:\LongTermRecording2002_present\ARPS\Prydz05\xwav\
%   Prydz 2006      W:\LongTermRecording2002_present\ARPS\Prydz06\xwav\
%
% See also: readXwavHeader, wavFolderInfo, xwavFolderInfo

addpath('c:\analysis\pamLtsa\');
addpath('c:\analysis\soundFolder\');

% -------------------------------------------------------------------------
%% CONFIGURE
% -------------------------------------------------------------------------
dryRun = false;   % set false to actually write files

deployments = {
    'Casey2004',     'W:\LongTermRecording2002_present\ARPS\Casey04\xwav\',      'W:\LongTermRecording2002_present\ARP-wav\Casey2004\'
    'Kerguelen2005', 'W:\LongTermRecording2002_present\ARPS\Kerguelen05\xwav\',  'W:\LongTermRecording2002_present\ARP-wav\Kerguelen2005\'
    'Kerguelen2006', 'W:\LongTermRecording2002_present\ARPS\Kerguelen06\xwav\',  'W:\LongTermRecording2002_present\ARP-wav\Kerguelen2006\'
    'Prydz2005',     'W:\LongTermRecording2002_present\ARPS\Prydz05\xwav\',      'W:\LongTermRecording2002_present\ARP-wav\Prydz2005\'
    'Prydz2006',     'W:\LongTermRecording2002_present\ARPS\Prydz06\xwav\',      'W:\LongTermRecording2002_present\ARP-wav\Prydz2006\'
};

% -------------------------------------------------------------------------
%% RUN
% -------------------------------------------------------------------------
if dryRun
    fprintf('=== DRY RUN — no files will be written ===\n\n');
else
    fprintf('=== CONVERTING xwav to wav ===\n\n');
end

totalSegments = 0;
totalErrors   = 0;

for iDep = 1:size(deployments, 1)
    depName   = deployments{iDep, 1};
    srcFolder = deployments{iDep, 2};
    dstFolder = deployments{iDep, 3};

    fprintf('--- %s ---\n', depName);
    fprintf('  Source: %s\n', srcFolder);
    fprintf('  Dest:   %s\n', dstFolder);

    if ~exist(srcFolder, 'dir')
        fprintf('  [SKIP] Source folder not found\n\n');
        continue
    end

    if ~dryRun
        if ~exist(dstFolder, 'dir')
            mkdir(dstFolder);
            fprintf('  Created output folder\n');
        end
    end

    xwavFiles = dir(fullfile(srcFolder, '*.wav'));
    fprintf('  Found %d xwav files\n', numel(xwavFiles));

    depSegments = 0;
    depErrors   = 0;

    parfor iFile = 1:numel(xwavFiles)
        srcPath = fullfile(srcFolder, xwavFiles(iFile).name);

        try
            header = readXwavHeader(srcPath);
        catch ME
            fprintf('  [ERROR] Could not read header: %s — %s\n', ...
                xwavFiles(iFile).name, ME.message);
            depErrors = depErrors + 1;
            continue
        end

        % Check if output already exists before reading large file
        dt      = datetime(header.startDate(1), 'ConvertFrom', 'datenum');
        outName = sprintf('%s.wav', datestr(dt, 'yyyy-mm-dd_HH-MM-SS'));
        outPath = fullfile(dstFolder, outName);
        if ~dryRun && exist(outPath, 'file')
            fprintf('  [SKIP] %s already exists\n', outName);
            continue
        end

        % Read entire xwav file once — audioread handles the proprietary
        % header chunks gracefully via libsndfile.
        try
            audio_all = audioread(srcPath);
        catch ME
            fprintf('  [ERROR] audioread failed: %s — %s\n', ...
                xwavFiles(iFile).name, ME.message);
            depErrors = depErrors + header.numberOfRawFiles;
            continue
        end

        sampleOffset = 0;

        for iSeg = 1:header.numberOfRawFiles
            try
                % Build output filename from embedded timestamp
                dt      = datetime(header.startDate(iSeg), 'ConvertFrom', 'datenum');
                outName = sprintf('%s.wav', datestr(dt, 'yyyy-mm-dd_HH-MM-SS'));
                outPath = fullfile(dstFolder, outName);
                nSamples = round(header.duration(iSeg) * header.sampleRate(iSeg));

                if dryRun
                    fprintf('  [DRY] %s seg%02d -> %s  (%.1f s, %d Hz, %d samples)\n', ...
                        xwavFiles(iFile).name, iSeg, outName, ...
                        header.duration(iSeg), header.sampleRate(iSeg), nSamples);
                elseif exist(outPath, 'file')
                    fprintf('  [SKIP] %s already exists\n', outName);
                else
                    segAudio = audio_all(sampleOffset+1 : sampleOffset+nSamples);
                    audiowrite(outPath, segAudio, header.sampleRate(iSeg), ...
                        'BitsPerSample', header.bitsPerSample);
                    fprintf('  [OK] %s\n', outName);
                end

                sampleOffset = sampleOffset + nSamples;
                depSegments  = depSegments + 1;

            catch ME
                fprintf('  [ERROR] %s seg%02d: %s\n', ...
                    xwavFiles(iFile).name, iSeg, ME.message);
                depErrors = depErrors + 1;
            end
        end
    end

    if dryRun
        wroteStr = 'would be written';
    else
        wroteStr = 'written';
    end
    fprintf('  %d segments %s, %d errors\n\n', depSegments, wroteStr, depErrors);

    totalSegments = totalSegments + depSegments;
    totalErrors   = totalErrors   + depErrors;
end

fprintf('=== TOTAL: %d segments, %d errors ===\n', totalSegments, totalErrors);
if dryRun
    fprintf('Set dryRun = false to perform conversion.\n');
    return
end

% -------------------------------------------------------------------------
%% VALIDATE
% -------------------------------------------------------------------------
fprintf('\n=== VALIDATING conversion ===\n\n');

tol    = 1/86400;  % 1 second in datenum units
passed = true;

for iDep = 1:size(deployments, 1)
    depName   = deployments{iDep, 1};
    srcFolder = deployments{iDep, 2};
    dstFolder = deployments{iDep, 3};

    fprintf('--- %s ---\n', depName);

    if ~exist(srcFolder, 'dir') || ~exist(dstFolder, 'dir')
        fprintf('  [SKIP] Folder not found\n\n'); continue
    end

    xInfo = xwavFolderInfo(srcFolder);
    wInfo = wavFolderInfo(dstFolder);

    xDur   = sum([xInfo.duration]);
    wDur   = sum([wInfo.duration]);
    xStart = min([xInfo.startDate]);
    wStart = min([wInfo.startDate]);
    xEnd   = max([xInfo.endDate]);
    wEnd   = max([wInfo.endDate]);

    fprintf('  Files:     xwav=%d  wav=%d\n',          numel(xInfo), numel(wInfo));
    fprintf('  Duration:  xwav=%.1f h  wav=%.1f h  diff=%.1f s\n', ...
        xDur/3600, wDur/3600, abs(xDur-wDur));
    fprintf('  Start:     xwav=%s  wav=%s  diff=%.1f s\n', ...
        datestr(xStart,'yyyy-mm-dd HH:MM:SS'), ...
        datestr(wStart,'yyyy-mm-dd HH:MM:SS'), ...
        abs(xStart-wStart)*86400);
    fprintf('  End:       xwav=%s  wav=%s  diff=%.1f s\n', ...
        datestr(xEnd,'yyyy-mm-dd HH:MM:SS'), ...
        datestr(wEnd,'yyyy-mm-dd HH:MM:SS'), ...
        abs(xEnd-wEnd)*86400);

    depPass = true;
    if abs(xDur - wDur) > 1
        fprintf('  [FAIL] Duration mismatch: %.1f s\n', abs(xDur-wDur));
        depPass = false;
    end
    if abs(xStart - wStart) > tol
        fprintf('  [FAIL] Start date mismatch: %.1f s\n', abs(xStart-wStart)*86400);
        depPass = false;
    end
    if abs(xEnd - wEnd) > tol
        fprintf('  [FAIL] End date mismatch: %.1f s\n', abs(xEnd-wEnd)*86400);
        depPass = false;
    end
    if depPass
        fprintf('  [PASS]\n');
    else
        passed = false;
    end
    fprintf('\n');
end

resultStr = {'FAIL', 'PASS'};
fprintf('=== VALIDATION RESULT: %s ===\n', resultStr{passed+1});
