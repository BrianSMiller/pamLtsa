% Example of how to check AAD recording for gaps
wavInfo = wavFolderInfo('M:\DDU2018\')

% Compare end time of each file with start time of next file to find gaps
gapMin = 24*60*([wavInfo(2:end).startDate]-[wavInfo(1:end-1).endDate]);
stem([wavInfo(1:end-1).startDate], gapMin); 
datetick('x'); 
ylim([0 70]); 
xlim(datenum(['2018-02-02 00:00:00';'2018-10-05 10:00:00'])); 
ylabel('Gap between files (minutes)');