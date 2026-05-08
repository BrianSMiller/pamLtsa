function gaps = getNoDataTimes(start,stop, m)
%gaps = getNoDataTimes(start,stop, m)
% For a set of MAR metadata, find all of the times with data gaps between
% start and stop time.
% Requirements/assumptions
%   Metadata timespans are in chronological order.  
%   Metadata timespans don't overlap. 
%   Start and stop times encompass all of the timespans

%% New approach, look at wav files using soundFolder

wavStart = cell(size(m));
wavEnd = cell(size(m));
for i = 1:length(m)
    info = wavFolderInfo(m(i).wavFolder);
    wavStart{i} = [info.startDate]';
    wavEnd{i} = [info.endDate]';
end
wavStart = reshape(vertcat(wavStart{:}).',1,[]);
wavEnd = reshape(vertcat(wavEnd{:}).',1,[]);

gapDuration = wavStart(2:end) - wavEnd(1:end-1);
gapIx = find(gapDuration > 1);
gapMiddle = [wavEnd(gapIx)' wavStart(gapIx+1)'];

gapStart = [datenum(start) min(wavStart)];
gapEnd = [max(wavEnd) datenum(stop)];
gaps = [gapStart; gapMiddle; gapEnd];
gaps = datetime(gaps,'ConvertFrom','datenum');
return;

%% Old approach looks only for gaps between metadata files.
% i = 1;
% gapStart(i) = start;
% gapStop(i) = datetime(m(i).startDate,'ConvertFrom','datenum');
% 
% for i = 2:length(m)
%     gapStart(i) = datetime(m(i-1).endDate,'ConvertFrom','datenum');
%     gapStop(i) = datetime(m(i).startDate,'ConvertFrom','datenum');
% end
% 
% % If length(m)<2, then i will be empty. Check and set it back to 1;
% if isempty(i); i = 1; end 
% 
% i = i+1;
% gapStart(i) = datetime(m(i-1).endDate,'ConvertFrom','datenum');
% gapStop(i) = stop;
% 
% gaps = [gapStart; gapStop]';
