%% test_functionSignatures.m
%
% Validates resources/functionSignatures.json for the pamLtsa folder.
%
% Custom tab completion is silent when it is wrong. MATLAB ignores a
% malformed or stale signatures file without any warning, so a broken
% entry looks exactly like no entry at all. This test makes that failure
% visible.
%
% Tests:
%   1. The signatures file exists where MATLAB expects it.
%   2. validateFunctionSignaturesJSON reports no errors.
%   3. Every function named in the file resolves on the path and lives in
%      the pamLtsa folder.
%   4. Every positional input name matches the name in the function
%      declaration, in order.
%   5. Every name-value input matches an options.<name> or addParameter
%      name in the source.
%   6. Every working top-level function in the folder has an entry.
%
% Data required:
%   None. Reads source files only.
%
% Expected result:
%   All checks [PASS]. Test 6 lists the deliberate exclusions: scripts and
%   the non-functional load_LTSA_folder.
%
% Note: MATLAB caches signatures at startup. After editing the JSON, run
% this test to confirm it parses, then restart MATLAB to see the change in
% the editor.
%
% See also: validateFunctionSignaturesJSON

%% Setup
pamLtsaDir = fileparts(which('wavFolderToLtsa'));
if isempty(pamLtsaDir)
    error('test_functionSignatures:notOnPath', ...
        'pamLtsa is not on the MATLAB path. addpath the repo folder first.');
end
jsonFile = fullfile(pamLtsaDir, 'resources', 'functionSignatures.json');

% Scripts and broken code are deliberately excluded from the signatures.
% Scripts take no arguments so tab completion does not apply, and
% load_LTSA_folder references undefined variables and cannot run.
excluded = {'checkForRecordingGaps', 'makeLtsa', 'xwavToWav', 'load_LTSA_folder'};

fprintf('pamLtsa folder: %s\n\n', pamLtsaDir);

%% 1. File exists
if isfile(jsonFile)
    fprintf('[PASS] functionSignatures.json found\n');
else
    fprintf('[FAIL] not found at %s\n', jsonFile);
    return
end

%% 2. MATLAB validation
issues = validateFunctionSignaturesJSON(jsonFile);
if isempty(issues)
    fprintf('[PASS] validateFunctionSignaturesJSON reports no errors\n');
else
    fprintf('[FAIL] validateFunctionSignaturesJSON reported issues:\n');
    disp(issues);
    return
end

sig = jsondecode(fileread(jsonFile));
names = fieldnames(sig);
names = names(~startsWith(names, 'x_'));   % jsondecode renames _schemaVersion
fprintf('       %d functions described\n\n', numel(names));

%% 3-5. Cross-check each entry against its source
nameFail = 0;
posFail  = 0;
nvFail   = 0;

for i = 1:numel(names)
    fn  = names{i};
    src = fullfile(pamLtsaDir, [fn '.m']);

    if ~isfile(src)
        fprintf('[FAIL] %s: no %s.m in the pamLtsa folder\n', fn, fn);
        nameFail = nameFail + 1;
        continue
    end

    [declName, declIn] = parseDeclaration(src);

    if ~strcmp(declName, fn)
        fprintf('[FAIL] %s.m declares function %s\n', fn, declName);
        nameFail = nameFail + 1;
    end

    inputs = sig.(fn).inputs;
    if isstruct(inputs), inputs = num2cell(inputs); end
    kinds  = cellfun(@(x) string(x.kind), inputs);
    inNames = cellfun(@(x) string(x.name), inputs);

    % Positional inputs, in order
    jsonPos = inNames(kinds == "required" | kinds == "ordered" | kinds == "optional");
    srcPos  = declIn(~ismember(declIn, ["varargin" "options"]));
    if ~isequal(jsonPos(:), srcPos(:))
        fprintf('[FAIL] %s: positional mismatch\n', fn);
        fprintf('       json: %s\n', strjoin(jsonPos, ', '));
        fprintf('       src:  %s\n', strjoin(srcPos, ', '));
        posFail = posFail + 1;
    end

    % Name-value inputs
    jsonNV = sort(inNames(kinds == "namevalue"));
    srcNV  = sort(parseNameValues(src, declIn));
    if ~isequal(jsonNV(:), srcNV(:))
        fprintf('[FAIL] %s: name-value mismatch\n', fn);
        fprintf('       json: %s\n', strjoin(jsonNV, ', '));
        fprintf('       src:  %s\n', strjoin(srcNV, ', '));
        nvFail = nvFail + 1;
    end
end

if nameFail == 0
    fprintf('[PASS] every described function resolves in the pamLtsa folder\n');
end
if posFail == 0
    fprintf('[PASS] positional argument names match every declaration\n');
end
if nvFail == 0
    fprintf('[PASS] name-value argument names match every declaration\n');
end

%% 6. Coverage
d = dir(fullfile(pamLtsaDir, '*.m'));
onDisk = string(erase({d.name}, '.m'));
missing = setdiff(setdiff(onDisk, string(names)), string(excluded));

if isempty(missing)
    fprintf('[PASS] every non-excluded top-level function has an entry\n');
    fprintf('       excluded by design: %s\n', strjoin(string(excluded), ', '));
else
    fprintf('[FAIL] no signature entry for: %s\n', strjoin(missing, ', '));
end

%% Helpers
function [name, inputs] = parseDeclaration(srcFile)
% Return the name and input argument names of the first function
% declaration in a file.
txt   = string(fileread(srcFile));
lines = splitlines(txt);
name    = "";
inputs  = string.empty(1,0);
for k = 1:numel(lines)
    tok = regexp(strtrim(lines(k)), ...
        '^function\s+(?:(?:\[[^\]]*\]|\w+)\s*=\s*)?(\w+)\s*\(([^)]*)\)', ...
        'tokens', 'once');
    if ~isempty(tok)
        name = tok(1);
        args = strtrim(split(tok(2), ','));
        inputs = args(strlength(args) > 0)';
        return
    end
end
end

function nv = parseNameValues(srcFile, declIn)
% Return the name-value argument names declared in a file, whether the
% function uses an arguments block (options.<name>) or inputParser
% (addParameter).
txt = string(fileread(srcFile));
if ismember("options", declIn)
    nv = string(regexp(txt, '(?m)^\s*options\.(\w+)', 'tokens'));
elseif ismember("varargin", declIn)
    nv = string(regexp(txt, "addParameter\(\s*\w+\s*,\s*'(\w+)'", 'tokens'));
else
    nv = string.empty(1,0);
end
nv = unique(nv);
end
