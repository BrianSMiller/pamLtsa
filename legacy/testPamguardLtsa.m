folder = 'D:\workInProgress\ddu2018-analysis\binary';
fileMask = 'LTSA_Long_Term_Spectral_Average_0.5_kHz_1_min_LTSA_*.pgdf';

% folder = 'D:\workInProgress\casey2018-analysis\binary\';
% fileMask = 'LTSA_Long_Term_Spectral_Average_12_kHz_1_hour_LTSA_*.pgdf';

folder = 'D:\workInProgress\kerguelen2018-analysis\binary';

verbose = 100;
channel=0; %use channel zero (these data are form one channel anyway)
plotLTSA=true; %true to autimaticall plot the LTSA
hsens=-165;%hydrophone sensitivity in dB re 1V/uPa
vp2p=1.5; %peak to peak voltage in dB
gain=20; %gain in dB
day_num_start=0; %time start
day_num_end=100000000; %time end
climits=[10,60]; %colour limits in dB root Hertz

%%
[ltsa_data, folderInfo] = loadPamguardBinaryFolder(folder, fileMask, verbose);

%%
fftLen = length(ltsa_data(1).data);
sampleRate = 500;
deltaF = sampleRate/2/fftLen;
f = [1:length(ltsa_data(1).data)] * deltaF;
t = [ltsa_data.date];
data = 20*log10([ltsa_data.data]);

surf(t,f,data,'lineStyle','none');
view(2)
datetick('x','m');
colorbar;
set(gca,'cLim',[-40 20])