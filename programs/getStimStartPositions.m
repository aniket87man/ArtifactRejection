% lfpInfo, parameterCombinations has to be loaded, doing only for elec1 
function dataStimStartPosns = getStimStartPositions(elecData, times, bline)  % amps, % thresFactor

% ampData = analogData(parameterCombinations{7, 1, 1, 5, 5, 4},:);

arguments
    elecData 
    times 
    bline = [-0.7 -0.1]
end

thresFactor = 10;  % 3, 5, 10
blpos = times>bline(1) & times<bline(2);

numTrials = size(elecData, 1);

commonShift = find(times>bline(2), 1);
dataMeans = zeros(1, numTrials); dataSTDs = zeros(1, numTrials); dataStimStartPosns = zeros(1, numTrials);

for idx = 1:size(elecData, 1)
    dat = elecData(idx,:);         % size(dat) is 1 x numTimePts
    dataMeans(idx) = mean(dat(blpos));
    std = 1/(size(dat(blpos), 2) - 1)*sum((dat(blpos) - mean(dat(blpos))).^2);
    std = sqrt(std);
    dataSTDs(idx) = std;
    
    stimStartPos = find(dat(times>-0.1)>(dataMeans(idx) + thresFactor*std) | dat(times>-0.1)<(dataMeans(idx) - thresFactor*std), 1);
    if isempty(stimStartPos)
        dataStimStartPosns(idx) = commonShift-1;
    else
        dataStimStartPosns(idx) = stimStartPos + commonShift-1;   % accounting for the fact that we are only looking at timeVals after -0.1 s
    % dataStimStartPosns(idx) = dataStimStartPosns(idx)-1;     % take the timept. just before the actual timeVal where the huge change occurs,
    end                                                         % as the stimStartpoint
end