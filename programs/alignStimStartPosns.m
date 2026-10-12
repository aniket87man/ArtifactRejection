% aligns the stimStartPosns. of all the trials corr. to one electrode and
% one microStimn. amplitude

function [elecStimStartPos, alignedData] = alignStimStartPosns(elecData, times, bline)

arguments
    elecData
    times
    bline = [-0.7 -0.1]
end

% figure; plot(times, elecData); 
% title('all Trials for current Electrode'); xlabel('time(s)'); ylabel('Voltage (\muV)')

elecStimStartPos = getStimStartPositions(elecData, times, bline);

% disp(max(elecStimStartPos));  disp(min(elecStimStartPos));

numTrials = size(elecData, 1);
T = times(2) - times(1);

% some checks
maxStimTimeVal = max(elecStimStartPos)*T + times(1); minStimTimeVal = min(elecStimStartPos)*T + times(1);
% disp([maxStimPos minStimPos mean(elecStimStartPos)*T+times(1)]);

% 1. centering around the trial that has the latest stimStartPosn
maxStimPos = max(elecStimStartPos);

diffsInStimStartPos = abs(elecStimStartPos - maxStimPos);

alignedData = zeros(size(elecData));
% % checking
% assignin('base', 'aa', alignedData);
% assignin('base', 'diffPos', diffsInStimStartPos);
for tr=1:numTrials
    alignedData(tr, diffsInStimStartPos(tr)+1:end) = elecData(tr, 1:end-diffsInStimStartPos(tr));
end

% figure; 
% plot(times, alignedData); 
% title('data after aligning Stimn. start points of all trials'); xlabel('time(s)'); ylabel('Voltage (\muV)');
