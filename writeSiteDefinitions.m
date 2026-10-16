function s = writeSiteDefinitions(m, outFile, options)
% writeSiteDefinitions  Write recorder metadata as a siteDefinitions JSON file.
%
% Turns an array of recorder metadata structs (as returned by
% loadRecorderMetaData or metaData<Code>) into the siteDefinitions.json
% format read by the 2026-CopernicusPyRAM transmission loss pipeline.
% One struct becomes one site entry. The function knows nothing about any
% particular study: the caller chooses which deployments to pass, and can
% set the optional fields below to control keys, names and groups.
%
% Usage:
%   writeSiteDefinitions(m, outFile)
%   writeSiteDefinitions(m, outFile, Group="aad")
%   s = writeSiteDefinitions(__)
%
% Inputs:
%   m        Struct array of recorder metadata. Required fields:
%              code       deployment code, e.g. 'Kerguelen2015'
%              latitude   decimal degrees N
%              longitude  decimal degrees E (-180 to 180 or 0 to 360)
%              depth      hydrophone depth, m below the sea surface
%              startDate  datenum or datetime
%              endDate    datenum or datetime
%            Optional fields (used when present and non-empty):
%              siteCode             JSON key. Default: code
%              name                 Readable name. Default: siteCode
%              group                Site group. Default: Group option
%              heightAboveBottom_m  Measured hydrophone height above the
%                                   seabed, m. Default: NaN (null in JSON)
%              elements             Cell array of the channel or element
%                                   codes in this entry. Default: {code}
%   outFile  Path of the JSON file to write. Use "" to skip writing.
%
% Optional name-value inputs:
%   Group    Group for entries without their own group field. Default: ""
%
% Output:
%   s        The struct that was encoded, one field per site.
%
% JSON fields written per site:
%   siteCode, name, latitude, longitude, lon360, depth_m,
%   hydrophone_height_above_bottom_m, group, year_first, year_last, elements
%
% Missing heights are written as null. The pipeline then uses depth_m.
%
% See also: loadRecorderMetaData

arguments
    m struct
    outFile (1,1) string
    options.Group (1,1) string = ""
end

required = {'code', 'latitude', 'longitude', 'depth', 'startDate', 'endDate'};
missing = required(~isfield(m, required));
if ~isempty(missing)
    error('writeSiteDefinitions:missingField', ...
        'Metadata is missing required field(s): %s', strjoin(missing, ', '));
end

s = struct();
for i = 1:numel(m)
    d = m(i);
    key = char(optionalField(d, 'siteCode', d.code));
    if ~isvarname(key)
        error('writeSiteDefinitions:badKey', ...
            '"%s" is not a valid key. Use letters, digits and underscores.', key);
    end
    if isfield(s, key)
        error('writeSiteDefinitions:duplicateKey', 'Duplicate site key "%s".', key);
    end
    mustBeScalarNumber(d.latitude, 'latitude', key);
    mustBeScalarNumber(d.longitude, 'longitude', key);
    mustBeScalarNumber(d.depth, 'depth', key);

    lon = d.longitude;
    if lon > 180
        lon = lon - 360;
    end

    e = struct();
    e.siteCode = key;
    e.name = char(optionalField(d, 'name', key));
    e.latitude = d.latitude;
    e.longitude = lon;
    e.lon360 = mod(lon, 360);
    e.depth_m = d.depth;
    e.hydrophone_height_above_bottom_m = optionalField(d, 'heightAboveBottom_m', NaN);
    e.group = char(optionalField(d, 'group', options.Group));
    e.year_first = yearOf(d.startDate);
    e.year_last = yearOf(d.endDate);
    e.elements = cellstr(optionalField(d, 'elements', {d.code}));
    s.(key) = e;
end

if strlength(outFile) > 0
    json = jsonencode(s, PrettyPrint=true);
    fid = fopen(outFile, 'w');
    if fid < 0
        error('writeSiteDefinitions:cannotWrite', 'Cannot open %s for writing.', outFile);
    end
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', json);
    fprintf('Wrote %d site(s) to %s\n', numel(m), outFile);
end
end

function v = optionalField(d, name, default)
% Field value if present and non-empty, otherwise the default.
if isfield(d, name) && ~isempty(d.(name))
    v = d.(name);
else
    v = default;
end
end

function mustBeScalarNumber(v, name, key)
if ~(isnumeric(v) && isscalar(v) && isfinite(v))
    error('writeSiteDefinitions:badValue', ...
        '%s for "%s" must be a single finite number.', name, key);
end
end

function y = yearOf(t)
% Calendar year of a datenum or datetime.
if isdatetime(t)
    y = year(t);
else
    y = year(datetime(t, 'ConvertFrom', 'datenum'));
end
end
