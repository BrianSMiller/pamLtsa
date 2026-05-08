function data = loadRecorderMetaData(code)
if nargin < 1
    code = '';
end
recordingSites ={...
    'casey2004','casey2014','casey2016','casey2017','casey2018',...
    'casey2019','casey2020','casey2022','casey2023','casey2024',...
    'ddu2018','ddu2019','ddu2021',...
    'kerguelen2005','kerguelen2006',... 
    'kerguelen2014','kerguelen2015','kerguelen2016','kerguelen2017',...
	'kerguelen2018','kerguelen2019','kerguelen2020','kerguelen2021',...
    'kerguelen2023','kerguelen2024',...
    'prydz2013','himi2017',...
    'kombi001_2021','kombi002_2021','kombi003_2021',...
    'kombi001_2024','kombi002_2024','kombi003_2024',...
    'meek001_2024','meek001_mar_2024'}; % 

if iscellstr(code)
        sites = code;
        data = loadRecorderMetaData(sites{1});
        for i = 2:length(sites)
            d = loadRecorderMetaData(sites{i});
            data = [data, d];
        end
        return
end

switch lower(code)
    case 'all'
        sites = {'casey','ddu','kerguelen','prydz'};
        data = loadRecorderMetaData(sites{1});
        for i = 2:length(sites)
            d = loadRecorderMetaData(sites{i});
            data = [data, d];
        end
    case 'casey'
        sites = {'casey2004','casey2014','casey2016','casey2017',...
            'casey2018','casey2019','casey2020','casey2022','casey2023',...
            'casey2024'};
        for i = 1:length(sites)
            data(i) = loadRecorderMetaData(sites{i});
        end
	case 'ddu'
        sites = {'ddu2018','ddu2019','ddu2021'};
        for i = 1:length(sites)
            data(i) = loadRecorderMetaData(sites{i});
        end
    case 'kerguelen'
        sites = {'kerguelen2005','kerguelen2006','kerguelen2014','kerguelen2015',...
            'kerguelen2016','kerguelen2017','kerguelen2018',...
            'kerguelen2019','kerguelen2020','kerguelen2021',...
            'kerguelen2023','kerguelen2024'};
        for i = 1:length(sites)
            data(i) = loadRecorderMetaData(sites{i});
        end
    case 'prydz'
        sites = {'prydz2005','prydz2006',... 
            'prydz2013','kombi003_2021'};
        for i = 1:length(sites)
            data(i) = loadRecorderMetaData(sites{i});
        end
    case 'kombi'
        sites = {'kombi001_2021','kombi002_2021','kombi003_2021',...
            'kombi001_2024','kombi002_2024','kombi003_2024'};
        for i = 1:length(sites)
            data(i) = loadRecorderMetaData(sites{i});
        end
    case 'casey2004'
        data = metaDataCasey2004;
    case 'casey2014'
        data = metaDataCasey2014;
    case 'casey2016'
        data = metaDataCasey2016;
    case 'casey2017'
        data = metaDataCasey2017;
    case 'casey2018'
        data = metaDataCasey2018;
    case 'casey2019'
        data = metaDataCasey2019;
    case 'casey2020'
        data = metaDataCasey2020;
    case 'casey2022'
        data = metaDataCasey2022;
    case 'casey2023'
        data = metaDataCasey2023;
    case 'casey2024'
        data = metaDataCasey2024;
    case 'ddu2018'
        data = metaDataDDU2018;
    case 'ddu2019'
        data = metaDataDDU2019;
    case 'ddu2021'
        data = metaDataDDU2021;
    case 'kerguelen2005'
        data = metaDataKerguelen2005;
    case 'kerguelen2006'
        data = metaDataKerguelen2006;
    case 'kerguelen2014'
        data = metaDataKerguelen2014;
    case 'kerguelen2015'
        data = metaDataKerguelen2015;
    case 'kerguelen2016'
        data = metaDataKerguelen2016;
    case 'kerguelen2017'
        data = metaDataKerguelen2017;
    case 'kerguelen2018'
        data = metaDataKerguelen2018;
    case 'kerguelen2019'
        data = metaDataKerguelen2019;
    case 'kerguelen2020'
        data = metaDataKerguelen2020;
    case 'kerguelen2021'
        data = metaDataKerguelen2021;
    case 'kerguelen2023'
        data = metaDataKerguelen2023;
    case 'kerguelen2024'
        data = metaDataKerguelen2024;
    case 'prydz2005'
        data = metaDataPrydz2005;
    case 'prydz2006'
        data = metaDataPrydz2006;
    case 'prydz2013'
        data = metaDataPrydz2013;
	case {'kombi001_2021'}
        data = metaDataKombi001_2021;
    case {'kombi002_2021'}
        data = metaDataKombi002_2021;
    case {'kombi003_2021','prydz2021'}
        data = metaDataKombi003_2021;
	case {'kombi001_2024'}
        data = metaDataKombi001_2024;
    case {'kombi002_2024'}
        data = metaDataKombi002_2024;
    case {'kombi003_2024'}
        data = metaDataKombi003_2024;
    case {'himi2017','himi2018'}
        data = metaDataHimi2018;
    case {'scott2019','niwa2019'}
        data = metaDataScott2019;
    case {'meek001_2024'}
        data = metaDataMeek001_2024;
    case {'meek001_mar_2024'}
        data = metaDataMeek001_MAR_2024;
    case lower({'H01W1_EDH','CapeLeeuwin','HA01W1','H01W1_','H01W1'})
        data = metaDataH01W1;
    case lower({'H08S1_EDH','DiegoGarcia','HA08S1','H08S1_','H08SW1'})
        data = metaDataH08S1;
    otherwise
        try
            fprintf('%s not in recording list; checking local path.\n', code);
            eval(['data = metaData' code ';']);
        catch
            warning('loadRecorderMetaData:notFound', ...
                ['Metadata function metaData%s not found.\n' ...
                 'Returning uncalibrated stub — calibration fields are NaN.\n' ...
                 'For official deployment metadata see the Australian Antarctic\n' ...
                 'Data Centre (https://data.aad.gov.au) or a future Tethys\n' ...
                 'backend (planned).'], code);
            data = struct( ...
                'site',               code, ...
                'code',               code, ...
                'hydroSensitivity_dB', NaN, ...
                'frontEndGain_dB',    NaN, ...
                'frontEndFreq_Hz',    NaN, ...
                'adPeakVolt',         NaN, ...
                'sampleRate',         NaN, ...
                'latitude',           NaN, ...
                'longitude',          NaN, ...
                'depth',              NaN, ...
                'startDate',          NaN, ...
                'endDate',            NaN, ...
                'ltsaFile',           '', ...
                'wavFolder',          '');
        end
end
