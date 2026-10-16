%% test_writeSiteDefinitions.m
%
% Unit test for writeSiteDefinitions. Uses two synthetic metadata structs,
% so it needs none of the private metaData<Code> functions. Checks the
% keys, default fields, null height, longitude wrapping and the round trip
% through jsondecode.
%
% See also: writeSiteDefinitions

fprintf('=== test_writeSiteDefinitions (%s) ===\n\n', datestr(now));

passed = true;
outFile = [tempname '.json'];
cleanup = onCleanup(@() delete(outFile));

% Two synthetic deployments: one plain, one with every optional field set
m(1).code = 'Test2015';
m(1).latitude = -62.38;
m(1).longitude = 81.79;
m(1).depth = 1800;
m(1).startDate = datenum(2015, 1, 10);
m(1).endDate = datenum(2016, 2, 1);

m(2).code = 'H01W1_EDH';
m(2).latitude = -34.89;
m(2).longitude = 245.0;            % 0-360 input, should wrap to -115
m(2).depth = 1063;
m(2).startDate = datetime(2014, 12, 8);
m(2).endDate = datetime(2026, 3, 18);
m(2).siteCode = 'CapeLeeuwin_H01W1';
m(2).name = 'Cape Leeuwin H01W1';
m(2).group = 'ctbto';
m(2).heightAboveBottom_m = 30;
m(2).elements = {'H01W1_EDH', 'H01W2_EDH'};

s = writeSiteDefinitions(m, outFile, Group="aad");
d = jsondecode(fileread(outFile));

% -------------------------------------------------------------------------
%% 1. Keys
% -------------------------------------------------------------------------
fprintf('--- 1. Keys come from siteCode, else code ---\n');
if isequal(sort(fieldnames(d)), sort({'Test2015'; 'CapeLeeuwin_H01W1'}))
    fprintf('[PASS] Keys as expected\n');
else
    fprintf('[FAIL] Unexpected keys: %s\n', strjoin(fieldnames(d), ', '));
    passed = false;
end

% -------------------------------------------------------------------------
%% 2. Defaults for the plain entry
% -------------------------------------------------------------------------
fprintf('--- 2. Defaults ---\n');
a = d.Test2015;
checks = { ...
    strcmp(a.name, 'Test2015'),            'name defaults to key'; ...
    strcmp(a.group, 'aad'),                'group defaults to Group option'; ...
    isempty(a.hydrophone_height_above_bottom_m), 'missing height is null'; ...
    a.year_first == 2015 && a.year_last == 2016, 'years from datenum'; ...
    strcmp(a.date_start, '2015-01-10') && strcmp(a.date_end, '2016-02-01'), 'ISO dates from datenum'; ...
    isequal(cellstr(a.elements), {'Test2015'}),  'elements defaults to {code}'; ...
    a.depth_m == 1800,                     'depth_m from depth'};
for k = 1:size(checks, 1)
    if checks{k, 1}
        fprintf('[PASS] %s\n', checks{k, 2});
    else
        fprintf('[FAIL] %s\n', checks{k, 2});
        passed = false;
    end
end

% -------------------------------------------------------------------------
%% 3. Optional fields and longitude wrapping
% -------------------------------------------------------------------------
fprintf('--- 3. Optional fields ---\n');
b = d.CapeLeeuwin_H01W1;
checks = { ...
    strcmp(b.group, 'ctbto'),                      'own group wins'; ...
    b.hydrophone_height_above_bottom_m == 30,      'height written'; ...
    abs(b.longitude - (-115)) < 1e-9,              'longitude wrapped to -180..180'; ...
    abs(b.lon360 - 245) < 1e-9,                    'lon360 in 0..360'; ...
    b.year_first == 2014 && b.year_last == 2026,   'years from datetime'; ...
    strcmp(b.date_start, '2014-12-08') && strcmp(b.date_end, '2026-03-18'), 'ISO dates from datetime'; ...
    numel(b.elements) == 2,                        'elements kept'};
for k = 1:size(checks, 1)
    if checks{k, 1}
        fprintf('[PASS] %s\n', checks{k, 2});
    else
        fprintf('[FAIL] %s\n', checks{k, 2});
        passed = false;
    end
end

% -------------------------------------------------------------------------
%% 4. Bad input is rejected
% -------------------------------------------------------------------------
fprintf('--- 4. Bad input ---\n');
bad = m(1);
bad.depth = NaN;
try
    writeSiteDefinitions(bad, "");
    fprintf('[FAIL] NaN depth was accepted\n');
    passed = false;
catch err
    if strcmp(err.identifier, 'writeSiteDefinitions:badValue')
        fprintf('[PASS] NaN depth rejected\n');
    else
        fprintf('[FAIL] Wrong error: %s\n', err.identifier);
        passed = false;
    end
end

fprintf('\n');
if passed
    fprintf('All tests passed.\n');
else
    fprintf('SOME TESTS FAILED.\n');
end
