function [ltsa_spectrum, ltsa_time, interval, ltsa_spectrumdB] =load_LTSA_folder(folder, fileMask, channel, day_start, day_end, plotLTSA, hsens, vp2p, gain, climits)
%% Load a folder of LTSA files and create an LTSA spectrum.
verbose = 0;

n=1;
for i=1:length(binary_files)-1
    [pathstr,name,ext] = fileparts(binary_files{i}) ;
    if ~isempty(strfind(name, 'LTSA'))
        [ltsa_data fileHeader fileFooter moduleheader modulefooter]=readLTSAData(binary_files{i});
        if (isstruct(moduleheader))
            interval=moduleheader.intervalSeconds;
        end
        for j=1:length(ltsa_data)
            ltsa_channels=getChannels(ltsa_data(j).channelMap);
            for k=1:length(ltsa_channels)
                if (ltsa_channels(k)==channel)
                    disp(['LTSA file found ' num2str(i)])
                    %add ltsa data to array.
                    ltsa_spectrum(:,n)=ltsa_data(j).data(:,k);
                    ltsa_time(n)=ltsa_data(j).date;
                    ltsa_nFFT(n)=ltsa_data(j).nFFT;
                    n=n+1;
                end
            end
        end
    end
end

day_num_start=datenum(day_start,'dd-mm-yyyy HH:MM:SS');
day_num_end=datenum(day_end,'dd-mm-yyyy HH:MM:SS');
index_OK=find(ltsa_time> day_num_start & ltsa_time<=day_num_end);
ltsa_time=ltsa_time(index_OK);
ltsa_spectrum=ltsa_spectrum(:,index_OK); %grid of values.

%% Plot the LTSA
fftsize=length(ltsa_spectrum(:,1));
if (plotLTSA)
    
    freqbin=sR/2/fftsize;
    %need to make a meshgrid
    [Xinterp,Yinterp] = meshgrid((1:length(ltsa_time))*(interval),(1:fftsize)*freqbin);
    
    [Xinterp,Yinterp] = meshgrid(ltsa_time,(1:fftsize)*freqbin);
    
    %%now plot a surface
    surf(Xinterp, Yinterp, ltsa_spectrum,'EdgeColor','none')
    colormap Hot;
    caxis([0.005 0.25])
    xlabel('Time (seconds)')
    ylabel('Frequency (kHz)');
    view(0,90) %%set view angle
    
end
end