function dataOut = getGRF(loadedData,loadedTimeVals,blRange,stRange,tapers,movingWin)   % let, we have cleaned for the whole duration
                                                                             % instead of only the analysisTimeRange
    if ~exist('tapers','var');             tapers = [1 1];                  end
    if ~exist('movingWin','var');          movingWin = [0.25 0.025];        end

    Fs = round(1/(loadedTimeVals(2)-loadedTimeVals(1)));
    signal = loadedData;
        
    % Setup multitaper
    params.tapers   = tapers;
    params.pad      = -1;
    params.Fs       = Fs;
    params.fpass    = [0 250];
    params.trialave = 1;  % Averaging across trials
    
    % ranges
    range = blRange;     % ensure diff(blRange) == diff(stRange) always
    rangePos = round(diff(range)*Fs);
    blPos = find(loadedTimeVals>=blRange(1),1)+ (1:rangePos);
    stPos = find(loadedTimeVals>=stRange(1),1)+ (1:rangePos);
    
    % PSDs
    [dataOut.SBL,dataOut.freqBL] = mtspectrumc(signal(:,blPos)',params);
    [dataOut.SST,dataOut.freqST] = mtspectrumc(signal(:,stPos)',params);
    dataOut.deltaPSD = 10*(log10(dataOut.SST) - log10(dataOut.SBL));
    
    % Time-frequency data
    [STF,timeTF,dataOut.freqTF] = mtspecgramc(signal',movingWin,params);
    timeTF = timeTF+loadedTimeVals(1)-1/Fs;
    dataOut.timeTF = timeTF;
    
    % Change in power from baseline
    blPosTF = intersect(find(timeTF>=blRange(1)),find(timeTF<blRange(2)));
    logS = log10(STF);
    blPower = mean(logS(blPosTF,:),1);
    logSBL = repmat(blPower,length(timeTF),1);
    dataOut.deltaTF = 10*(logS - logSBL);
    dataOut.STF = STF;
    
    % Information about the ranges
    dataOut.blRange = blRange;
    dataOut.stRange = stRange;

end