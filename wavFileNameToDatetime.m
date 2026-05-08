function fileTime = wavFileNameToDatetime(t,embeddedDateFormat)

try
    fileTime = datetime(extractBetween(t.("Begin File"),'','.'),...
        'InputFormat',embeddedDateFormat);
catch
    try    % Maud rise
        fileTime = datetime(extractBefore(t.("Begin File"),16),...
            'InputFormat',embeddedDateFormat);
    catch
        try
            timeStr =  replaceBetween(t.("Begin File"),1,'_','',...
                'Boundaries','inclusive');
            timeStr = replace(timeStr,'.wav','');
            fileTime = datetime(timeStr,'InputFormat',embeddedDateFormat);
        catch
            try % Kerguelen 2014 & Casey 2014
                fileTime = datetime(extractBetween(t.("Begin File"),5,23),...
                    'InputFormat',embeddedDateFormat);
            catch
                try % Kerguelen 2015 & Casey 2015
                    fileTime = datetime(extractBetween(t.("Begin File"),3,21),...
                        'InputFormat',embeddedDateFormat);
                catch
                    try % Kerguelen 2018 & Casey 2018
                        fileTime = datetime(extractBetween(t.("Begin File"),4,22),...
                            'InputFormat',embeddedDateFormat);
                    catch
                        error(lasterr);
                    end
                end
            end
        end
    end
end
end