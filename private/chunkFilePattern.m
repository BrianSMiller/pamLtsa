function patterns = chunkFilePattern(stem, increment)
% chunkFilePattern  Return glob pattern(s) for chunked LTSA files.
%
% Private utility for catLtsa. Returns the glob pattern(s) matching chunk
% files produced by wavFolderToLtsa for a given stem and increment type.
% Keeps glob patterns in sync with makeChunkFilename conventions.
%
% Inputs:
%   stem       File stem string, e.g. "S:\ltsa\kerguelen2025_ALTO_ch1_3600s_1Hz"
%   increment  "daily", "monthly", "yearly", or "any" (returns all patterns)
%
% Output:
%   patterns   String array of glob patterns
%
% See also: makeChunkFilename, catLtsa, wavFolderToLtsa

arguments
    stem      (1,1) string
    increment (1,1) string = "any"
end

daily   = stem + "_????-??-??.mat";
monthly = stem + "_????-??.mat";
yearly  = stem + "_????.mat";

switch increment
    case "daily";   patterns = daily;
    case "monthly"; patterns = monthly;
    case "yearly";  patterns = yearly;
    case "any";     patterns = [daily, monthly, yearly];
    otherwise
        error('chunkFilePattern:badIncrement', ...
            'increment must be "daily", "monthly", "yearly", or "any"');
end
end
