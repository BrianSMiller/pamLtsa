function chunkFile = makeChunkFilename(saveFile, chunkStart, increment)
% makeChunkFilename  Construct a chunk filename from a saveFile stem and date.
%
% Private utility for wavFolderToLtsa and catLtsa. Encodes the filename
% convention for chunked LTSA files so both functions stay in sync.
%
% Inputs:
%   saveFile    Full path to the base .mat file (e.g. "S:\ltsa\foo.mat")
%   chunkStart  MATLAB datenum of the chunk start time
%   increment   "daily", "monthly", or "yearly"
%
% Output:
%   chunkFile   Full path with date suffix, e.g. "S:\ltsa\foo_2025-02.mat"
%
% See also: chunkFilePattern, wavFolderToLtsa, catLtsa

[folder, stem, ~] = fileparts(saveFile);
dt = datetime(chunkStart, 'ConvertFrom', 'datenum');
switch increment
    case "daily";   suffix = datestr(dt, 'yyyy-mm-dd');
    case "monthly"; suffix = datestr(dt, 'yyyy-mm');
    case "yearly";  suffix = datestr(dt, 'yyyy');
    otherwise
        error('makeChunkFilename:badIncrement', ...
            'increment must be "daily", "monthly", or "yearly"');
end
chunkFile = fullfile(folder, sprintf('%s_%s.mat', stem, suffix));
end
