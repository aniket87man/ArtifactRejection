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
segment = (stimStartPos):(stimStartPos+13000);  % there are 7-8 artifacts each with 1500 samples  % length(medianSig) too huge
nTrials = size(stimData, 1);

corruptedSigs = stimData(:, segment);
cleanedSigs = zeros(nTrials, length(segment));   % 20000
dtwAlignedTrials = cell(1, nTrials);
dtwAlignedTemplates = cell(1, nTrials);
dtwDists = zeros(1, nTrials);
dtwLengths = zeros(size(dtwDists));

template = medianSig(:, segment);

%%
for trialIdx=1:nTrials
    dtwtimer = tic;
    % fprintf('trial %d being fitted using DTW\n', i);
    trial = stimData(trialIdx, segment);

    % [dist, ix, iy] = dtw(template, trial);
    % dtwDists(i) = dist;
    % dtwLengths(i) = length(ix);
    % cleaned = template(ix) - trial(iy);
    % cleanedSigs(i, 1:length(ix)) = cleaned;

    % [dist, trialAlgn, templateAlgn, pathXY, info] = dtwAlign(trial, template, 'Norm', 'l2');
    % [dist, trialAlgn, templateAlgn, pathXY, info] = dtwAlign(trial, template, 'Norm', 'l2', 'Constraint', 'sakoechiba', 'Radius', 100, 'Normalize', true);
    [dist, trialAlgn, templateAlgn, pathXY, info] = dtwAlign(trial, template, 'Norm', 'l2', 'Constraint', 'itakura', 'Normalize', true);

    dtwDists(trialIdx) = dist;
    dtwLengths(trialIdx) = info.pathLength;
    cleaned = trialAlgn - templateAlgn;

    dtwAlignedTrials{trialIdx} = trialAlgn;
    dtwAlignedTemplates{trialIdx} = templateAlgn;
    cleanedSigs(trialIdx, :) = interp1(linspace(0, 1, info.pathLength), cleaned, linspace(0, 1, length(segment)), 'linear');

    elapsed = toc(dtwtimer);
    fprintf('trial %d fitted using DTW in %.4f s\n', trialIdx, elapsed);
    % pause;
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

% figure;
% for trialIdx=1:nTrials
%     plot(cleanedSigs(trialIdx, :)); disp(trialIdx);
%     xlabel('# samples'); ylabel ('volt (\muV)')
%     title(sprintf('trial %d cleaned signal', trialIdx));
%     pause
% end
figure;
trialIdx=1;
plot(cleanedSigs(trialIdx, :));
xlabel('# samples'); ylabel ('volt (\muV)')
title(sprintf('trial %d cleaned signal', trialIdx));


%%
% noStimData for comparison

noStimPortion = noStimData(:, segment);

% noStim psd
figure; 
plot(10*log10(mean(abs(fft(noStimPortion')'), 1)))
hold on; plot(10*log10(mean(abs(fft(cleanedSigs')'), 1)))
xlim([0 150]);
xlabel('freq(Hz)'); ylabel('dB')
title('mean logPSD of noStim & cleaned signals')
legend('noStim', 'cleaned')

% time-domain

% figure;
% for trialIdx=1:size(noStimData, 1)
%     plot(noStimPortion(trialIdx, :)); disp(trialIdx);
%     xlabel('# samples'); ylabel ('volt (\muV)')
%     title(sprintf('trial %d noStim signal', trialIdx));
%     pause
% end
figure;
trialIdx=1;
plot(noStimPortion(trialIdx, :));
xlabel('# samples'); ylabel ('volt (\muV)')
title(sprintf('trial %d noStim signal', trialIdx));

