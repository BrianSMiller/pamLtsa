function [effort, effortSS, effortWav] = getRecordingEffort(m,binMethod)
if nargin < 2
    binMethod = 'year';
end
[effortSS, effortWav] = effortHoursPerYear(m);
effortSS = table(effortSS(:),'VariableNames',{'datetime'});

try
    if strcmpi(binMethod,'season')
        effortWav.season = season(effortWav.datetime);
        effort = groupsummary(effortWav,{'site','datetime','season'}, ...
            {'none','year','none'}, 'sum','duration_h', ...
            'IncludeEmptyGroups',true,'IncludeMissingGroups',true);
    else
        effort = groupsummary(effortWav,{'datetime','site'}, ...
            {binMethod,'none'}, 'sum','duration_h', ...
            'IncludeEmptyGroups',true,'IncludeMissingGroups',true);
        %     effort = groupsummary(effortWav,'datetime',binMethod,'sum','duration_h', ...
        %         'IncludeEmptyGroups',true)
    end
catch
    effort = groupsummary(effortSS,'allHours',binMethod, ...
        'IncludeEmptyGroups',true,'IncludeMissingGroups',true);
end
switch(binMethod)
    case {'year','season'}
        effort.datetime = datetime(str2double(string(effort.year_datetime)),1,1);
    case 'month'
        effort.datetime = datetime(string(effort.month_datetime));
    case 'week'
        effort.datetime = datetime( ...
            extractBetween(string(effort.week_datetime),'[',',') )
    case 'day'
        effort.datetime = datetime(string(effort.day_datetime));
end

effort.site = categorical(effort.site);

function [all, wav] = effortHoursPerYear(m)
h(:,1) = datetime([m.startDate]','ConvertFrom','datenum');
h(:,2) = datetime([m.endDate]','ConvertFrom','datenum');
all = [];
wav = [];
% find fields to remove with:
%   setdiff(fieldnames(xwavFolderInfo(m(1).wavFolder)),fieldnames(wavInfo))
xwavFieldsToRemove = {'byteLength','byteLoc','dataBlockType',...
    'numberOfRawFiles','padding','rawFileId','writeLength'};
for i = 1:size(h,1)
    all = [all, h(i,1):hours(1):h(i,2)];
    if exist(m(i).wavFolder,'dir')
        try
             % Old ARPs use different function for folder info
            if ismember(m(i).code,{'Kerguelen2005','Kerguelen2006', ...
                    'Casey2004', ...
                    'Prydz2005','Prydz2006'})
                wavInfo = xwavFolderInfo(m(i).wavFolder);
                wavInfo = rmfield(wavInfo,xwavFieldsToRemove);
            else % AAD MAR is just a folder of wav files
                wavInfo = wavFolderInfo(m(i).wavFolder);
            end
            [wavInfo.site] = deal(m(i).site);
            wav=[wav; struct2table(wavInfo)];
        catch
            l = lasterror
            keyboard
        end
    end
end
wav.duration_h = wav.duration/3600;
wav.datetime = datetime(wav.startDate,'ConvertFrom','datenum');

