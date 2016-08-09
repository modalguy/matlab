%% Demonstration of audio input of 333D01, using basic Windows audio drivers
%
% Given a sample rate, block size, and average count, Captures data using
% the windows audio drivers and computes a Fourier spectrum.
% Can optionally specify a target frequency, otherwise the function will
% find the highest amplitude peak (frequency domain-wise) and center on it.

clear hAR y yHist xt1 xt2 xs1 xs2 xavg1 xavg2 xtaxis xfaxis
prompt = {'# Averages',sprintf('Sample rate\n(What you selected through Windows->Sound->Recording->Properties->Advanced)\nValid options are 8000, 11025 16000, 22050, 32000, 44100, 48000'),'Block size (max 65536)','Window'};
% Important note: The 333D01 only supports sample rates of:
% 8000Hz, 11025Hz, 16000Hz, 22050Hz, 32000Hz, 44100Hz, 48000Hz
answer  = inputdlg(prompt,'Acquisition',1,{'30','48000','16384','flattop'});
ansarr = cellfun(@str2num,answer(1:end-1));
window = answer{end};
NUM_AVERAGES = ansarr(1);
samplerate = ansarr(2);
blksize = ansarr(3);
[SN, calA, calB, calDate, vers] = DigiDecoder;
sensitivityA_user = calA(1);
sensitivityB_user = calB(1);
if sensitivityA_user > 10000
    %Entered counts / m/s^2
    sensitivity_ctpmps2A = sensitivityA_user;
elseif sensitivityA_user > 40 && sensitivityA_user < 80
    % is incorrect old unit, mV/m/s^2
    sensitivity_ctpmps2A = sensitivityA_user*2^23/(1000*sqrt(2)*9.80665);
end
if sensitivityB_user > 10000
    %Entered counts / m/s^2
    sensitivity_ctpmps2B = sensitivityB_user;
elseif sensitivityB_user > 100 && sensitivityB_user < 140
    % is incorrect old unit, mV/m/s^2
    sensitivity_ctpmps2B = sensitivityB_user*2^23/(1000*sqrt(2)*9.80665);
end
scaleFactorA = 2^23 / sensitivity_ctpmps2A;
scaleFactorB = 2^23 / sensitivity_ctpmps2B;
% set this to true to accumulate all time data
plotAllTime = false;
%initialize the audiorecorder
hAR = audiorecorder(samplerate,24,2,1);
% if you get an error here about device id, run "a=audiodevinfo", and check
% a.input(n) for all n devices shown to check the IDs of the devices.
pause(1); % To give the figure window time to open
figh = figure;
% set up handles to subplot regions
sp(1) = subplot(3,1,1);     % Time
sp(2) = subplot(3,1,2);     % Frequency
sp(3) = subplot(3,1,3);     % Frequency avg
% Axis scaling
xtaxis = (1/hAR.samplerate)*(0:blksize-1);
xfaxis = (hAR.samplerate/(blksize))*(0:(blksize/2)-1);

if plotAllTime
    % initialize the all-time-history variable for speed
    yHist = zeros(blksize*NUM_AVERAGES,2);
end
% do this N times for N averages
for i=1:NUM_AVERAGES
    % Input data
    % the 1.5 is to make sure that we get at least blksize points.
    recordblocking(hAR,(blksize/samplerate)*1.5);
    % get the data and block it
    yt = getaudiodata(hAR);
    y = yt(1:blksize,:);
    if plotAllTime
        yHist((i-1)*blksize+1:(i*blksize),:) = y;
    end
	set(0,'CurrentFigure',figh);
	% Select time data display
    if i == 1
        subplot(sp(1));
        p1 = plot(xtaxis,y(:,1).*scaleFactorA,xtaxis,y(:,2).*scaleFactorB);
        xlabel('Time (s)');
        ylabel(sprintf('Acceleration\n(m/s^2)'));
        xlim([0 max(xtaxis)]);
    else
        set(p1(1),'XData',xtaxis,'YData',y(:,1).*scaleFactorA);
        set(p1(2),'XData',xtaxis,'YData',y(:,2).*scaleFactorB);
    end
	% Compute amplitude of time history for this average sample
	timeDomMax1(i) = max(y(:,1)*scaleFactorA);
	timeDomMax2(i) = max(y(:,2)*scaleFactorB);
	% get time history for channel A
	xt1 = y(:,1);
	% Compute spectrum for channel A
	xs1=spectralcalc(xt1,1,blksize-1,window); % scaling the halved channel to get the correct vibration amplitude
	% get time history for channel B
	xt2 = y(:,2);
	% Compute spectrum for channel B
	xs2=spectralcalc(xt2,1,blksize-1,window);
	% averaging
	if i == 1
		% Channel A average for first sample is itself
		xavgsum1 = xs1.Magnitude;
		% Channel B average for first sample is itself
		xavgsum2 = xs2.Magnitude;
	else
		% Channel A average
		xavgsum1 = xavgsum1+xs1.Magnitude;
		% Channel B average
		xavgsum2 = xavgsum2+xs2.Magnitude;
	end
	% Compute peak statistics to adjust display
   [~,peakFreqInd] = max(xs2(1).Magnitude*scaleFactorB);
    peakFreq = xfaxis(peakFreqInd); 
    peakFreqMag = xs2(1).Magnitude(peakFreqInd)*scaleFactorB;
   if i == 1
        subplot(sp(2));
        p2 = semilogx(xfaxis,20.*log10(xs1(1).Magnitude*scaleFactorA),xfaxis,20.*log10(xs2(1).Magnitude*scaleFactorB));
        xlabel('Frequency (Hz)'),ylabel(sprintf('Acceleration\n(dB of m/s^2)'));
        % Keep legend out of the way
        if peakFreq < 500
            legend('Ch 1','Ch 2','location','NorthEast');
        elseif peakFreq >= 500
            legend('Ch 1','Ch 2','location','NorthWest');
        end;
        grid on;
        xlim([0 10000]);
        ylim([-70 mag2db(peakFreqMag)+10]); 
    else
        set(p2(1),'XData',xfaxis,'YData',20.*log10(xs1(1).Magnitude*scaleFactorA));
        set(p2(2),'XData',xfaxis,'YData',20.*log10(xs2(1).Magnitude*scaleFactorB));
    end
	
    if i == 1
        subplot(sp(3));
        p3 = semilogx(xfaxis,20.*log10(xavgsum1/min(i,NUM_AVERAGES)*scaleFactorA),xfaxis,20.*log10(xavgsum2/min(i,NUM_AVERAGES)*scaleFactorB));
        xlabel('Frequency (Hz)'),ylabel(sprintf('Avg Acceleration\n(dB of m/s^2)\nAvg #: %i',i));
        % keep legend out of the way
        if peakFreq < 500
            legend('Ch 1','Ch 2','location','NorthEast');
        elseif peakFreq >= 500
            legend('Ch 1','Ch 2','location','NorthWest');
        end;
        grid on;
        xlim([0 10000]);
        ylim([-70 mag2db(peakFreqMag)+10]); 
    else
        set(p3(1),'XData',xfaxis,'YData',20.*log10(xavgsum1/min(i,NUM_AVERAGES)*scaleFactorA));
        set(p3(2),'XData',xfaxis,'YData',20.*log10(xavgsum2/min(i,NUM_AVERAGES)*scaleFactorB));
        ylabel(sprintf('Avg Acceleration\n(dB of m/s^2)\nAvg #: %i',min(i,NUM_AVERAGES)));
    end
    % force draw
    drawnow();
end
% Compute averaged statistics on identified peak frequencies and their
    % magnitudes, as well as time history amplitude
    [~,avgPeakFreqInd1] = max(xavgsum1*scaleFactorA/NUM_AVERAGES);
    [~,avgPeakFreqInd2] = max(xavgsum2*scaleFactorB/NUM_AVERAGES);
    peakAvgFreq1 = xfaxis(avgPeakFreqInd1);
    peakAvgFreq2 = xfaxis(avgPeakFreqInd2);
    avgPeakAmplitude1 = 20*log10(max(xavgsum1)*scaleFactorA/NUM_AVERAGES);
    avgPeakAmplitude2 = 20*log10(max(xavgsum2)*scaleFactorB/NUM_AVERAGES);
    avgTimePeakAmplitude1 = mean(timeDomMax1);
    avgTimePeakAmplitude2 = mean(timeDomMax2);
    % print out summary
    fprintf('Ch.A Peak Frequency: %.2f Hz. Ch.A Peak magnitude: %.3f dB acceleration. Ch.A Peak time amp: %.4f m/s^2\n',peakAvgFreq1,avgPeakAmplitude1,avgTimePeakAmplitude1);
    fprintf('Ch.B Peak Frequency: %.2f Hz. Ch.B Peak magnitude: %.3f dB acceleration. Ch.B Peak time amp: %.4f m/s^2\n\n',peakAvgFreq2,avgPeakAmplitude2,avgTimePeakAmplitude2);

% create a plot of the total time history signal for all devices, separated
% into channel As and channel Bs
if plotAllTime
    figure(2);
    cla;
    figure(3);
    cla;
    %create new figure for all devices, 
    % one for ch a and another for ch b
    figure(2);
    hold all;
    plot(1/hAR.SampleRate.*[1:length(yHist(:,1))],yHist(:,1)*scaleFactorA);
    title('Channel A');
    xlabel('Time (s)');
    ylabel('Acceleration (m/s^2)');
    figure(3);
    hold all;
    plot(1/hAR.SampleRate.*[1:length(yHist(:,2))],yHist(:,2)*scaleFactorB);
    title('Channel B');
    xlabel('Time (s)');
    ylabel('Acceleration (m/s^2)');
end
% remove unimportant variables to avoid clogging workspace
clear prompt answer ansarr plotAllTime