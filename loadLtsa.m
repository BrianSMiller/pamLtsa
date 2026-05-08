function [ltsa, freqs, t] = loadLtsa(ltsaFile, startDate, endDate)
% function [ltsa, freqs, t] = loadLtsa(ltsaFile, startDate, endDate);

% Round start and end date to nearest hour
sd = datenum(...
        dateshift(...
            datetime(startDate,'ConvertFrom','datenum'),"start",'hour'));
ed = datenum(...
        dateshift(...
            datetime(endDate,'ConvertFrom','datenum'),"start",'hour'));

load(ltsaFile,'-mat','ltsa','freqs','t');

% length of t can sometimes be one longer than LTSA: check & fix off-by-1
if length(t) >= size(ltsa,2)
    t = t(1:size(ltsa,2));
end
validData = find(t >= sd & t <= ed);
t = t(validData);
ltsa = ltsa(:,validData);

