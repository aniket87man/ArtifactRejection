clear;
clc;
% close


%%

stimDataFileContents = load('/Users/aniketmandal/Documents/MATLAB/SupiLabProgramsDatas/ArtifactRejection/data/amp64.mat');
stimData = stimDataFileContents.rawData;

noStimDataFileContents = load('/Users/aniketmandal/Documents/MATLAB/SupiLabProgramsDatas/ArtifactRejection/data/amp0.mat');
noStimData = noStimDataFileContents.rawData;

timesFileContents = load('/Users/aniketmandal/Documents/MATLAB/SupiLabProgramsDatas/ArtifactRejection/data/times.mat');
times = timesFileContents.timeValsRaw;

[stimStartPos, stimData] = alignStimStartPosns(stimData, times);
stimStartPos = max(stimStartPos);

bline = [-0.5, -0.1];
blpos = times>bline(1) & times<bline(2);

% remove DC (baseline correction)
stimData = removeDC(stimData, blpos);
noStimData = removeDC(noStimData, blpos);

% get median, used as template
medianSig = median(stimData, 1, 'omitnan');

% look at only the stimulated time-frame
segment = (stimStartPos-100):(stimStartPos + 1500);  % there are 7-8 artifacts each with 1500 samples

cleanedSigs = zeros(size(stimData, 1), 2500);   % 20000
corruptedSigs = stimData(:, segment);
dtwDists = zeros(1, size(stimData, 1));
dtwLengths = zeros(size(dtwDists));

template = medianSig(:, segment);

for i=1:size(stimData, 1)
    fprintf('trial %d being fitted using DTW\n', i);
    trial = stimData(i, segment);
    [dist, ix, iy] = dtw(template, trial);
    dtwDists(i) = dist;
    dtwLengths(i) = length(ix);
    cleaned = template(ix) - trial(iy);
    cleanedSigs(i, 1:length(ix)) = cleaned;
end


%% visualisation

close all

% psd
figure; 
plot(10*log10(mean(abs(fft(cleanedSigs')'), 1)))
xlim([0 150]);
xlabel('freq(Hz)'); ylabel('dB')
title('mean logPSD of cleaned signals')

% time-domain
figure;
for i=1:size(stimData, 1)
    plot(cleanedSigs(i, :)); disp(i);
    xlabel('# samples'); ylabel ('volt (\muV)')
    title(sprintf('trial %d cleaned signal', i));
    pause
end


%%
% noStimData for comparison

noStimPortion = noStimData(:, segment(1):segment(1)+2500);

% noStim psd
figure; 
plot(10*log10(mean(abs(fft(noStimPortion')'), 1)))
xlim([0 150]);
xlabel('freq(Hz)'); ylabel('dB')
title('mean logPSD of noStim signals')

% time-domain
figure;
for i=1:size(noStimData, 1)
    plot(noStimPortion(i, :)); disp(i);
    xlabel('# samples'); ylabel ('volt (\muV)')
    title(sprintf('trial %d noStim signal', i));
    pause
end


