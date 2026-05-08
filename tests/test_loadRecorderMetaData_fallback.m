%% test_loadRecorderMetaData_fallback.m
%
% Unit test for graceful fallback behaviour when metaDataSiteYear function
% is not available. Verifies that loadRecorderMetaData returns a stub struct
% with NaN calibration fields, and that calibrateLtsa handles NaN calibration
% by returning uncalibrated output rather than erroring.
%
% This is the key test enabling pamLtsa to be public without
% requiring the private metaDataSiteYear functions.
%
% See also: loadRecorderMetaData, calibrateLtsa

fprintf('=== test_loadRecorderMetaData_fallback (%s) ===\n\n', datestr(now));

addpath('c:\analysis\pamLtsa\');

passed = true;

% -------------------------------------------------------------------------
%% 1. Stub struct returned for unknown site
% -------------------------------------------------------------------------
fprintf('--- 1. Unknown site returns stub struct ---\n');
warnState = warning('off', 'loadRecorderMetaData:notFound');
data = loadRecorderMetaData('nonexistentSite2024');
warning(warnState);

if ~isstruct(data)
    fprintf('[FAIL] Expected struct, got %s\n', class(data));
    passed = false;
elseif ~isnan(data.hydroSensitivity_dB)
    fprintf('[FAIL] Expected NaN hydroSensitivity_dB\n');
    passed = false;
elseif ~isnan(data.adPeakVolt)
    fprintf('[FAIL] Expected NaN adPeakVolt\n');
    passed = false;
else
    fprintf('[PASS] Stub struct returned with NaN calibration fields\n');
end

% -------------------------------------------------------------------------
%% 2. calibrateLtsa handles NaN calibration gracefully
% -------------------------------------------------------------------------
fprintf('--- 2. calibrateLtsa with NaN calibration ---\n');
nFreqs  = 100;
nSlices = 10;
ltsa_in = rand(nFreqs, nSlices);
freqs   = (0:nFreqs-1)';

warnState = warning('off', 'calibrateLtsa:noCalibration');
[ltsa_out, caldB] = calibrateLtsa(ltsa_in, freqs, data);
warning(warnState);

if ~all(caldB == 0)
    fprintf('[FAIL] Expected zero caldB for NaN calibration\n');
    passed = false;
elseif ~isequal(size(ltsa_out), size(ltsa_in))
    fprintf('[FAIL] Output size mismatch\n');
    passed = false;
elseif max(abs(ltsa_out(:) - 10*log10(ltsa_in(:)))) > 1e-10
    fprintf('[FAIL] Output should be 10*log10(input) with zero offset\n');
    passed = false;
else
    fprintf('[PASS] Uncalibrated output returned with zero dB offset\n');
end

% -------------------------------------------------------------------------
%% Summary
% -------------------------------------------------------------------------
resultStr = {'FAIL', 'PASS'};
fprintf('\n=== RESULT: %s ===\n', resultStr{passed+1});
