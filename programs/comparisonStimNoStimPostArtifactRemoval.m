%% want to plot spectrogram, coherence, and power in specific freq band to compare noStimTrial and artifact-removed stimTrial, to see how artifact removal techniques are fairing, want to use same methods as supiLab does
% ver 1.0.0 - Aug 16, Aniket Mandal

%% Data from previous experiences we can use
% for elec1, trial 42, baseline-corrected, aligned-->
%   post-cleaning spike locations-
% 0.0417 .0481
% .0917 .098
% .1416 .1467
% .1916 .1978
% .2415 .2484
% .2915 .3
% .3413 .3423

% %  for fitting curve to the median itself
% sigmoid ranges->
% .0426 .0502

% % for elec42, trial 106 differs a lot from median

%% Single-template fitting with MATLAB lsqcurvefit
%
% % MODEL
%   summed(t) = medianArtifact(t) + noStimTrial(t)
%
%   fittedArtifact(t; p) = gain * medianArtifact(t - shift)
%
%   p = [gain, shiftSeconds]
%
%   lsqcurvefit estimates p by minimizing
%
%       sum_n (fittedArtifact(t_n; p) - summed(t_n))^2
%
%   subject to
%
%       gain >= 0
%       -maximumShiftSeconds <= shiftSeconds <= maximumShiftSeconds.
%
% WHY THIS VERSION IS EASY TO TRACE
%   1. There is one complete, data-derived artifact template.
%   2. There are only two fitted parameters: gain and time shift.
%   3. There is no fitted constant or polynomial baseline.
%   4. Baseline is removed independently using pre-stimulation samples.
%   5. MATLAB's documented lsqcurvefit solver performs the optimization.
%
% PRIMARY SOFTWARE/MATHEMATICAL SOURCE
%   MATLAB Optimization Toolbox, lsqcurvefit:
%   https://www.mathworks.com/help/optim/ug/lsqcurvefit.html
%
%   The bound-constrained default is the trust-region-reflective method:
%   Coleman TF, Li Y. SIAM Journal on Optimization. 1996;6:418-445.
%   doi:10.1137/0806023
%
% REQUIREMENT
%   MATLAB Optimization Toolbox is required for lsqcurvefit.

clear;
% close all;
clc;


%% 1. Editable data settings

subjectName = 'dona';
expDate = '290825';
protocolName = 'GRF_001';
folderSourceString = '/Users/aniketmandal/Documents/MATLAB/SupiLabProgramsDatas';
gridType = 'Microelectrode';
electrodeNumber = 42;   % 1, 42

dataSource = 'Raw';                 % 'LFP' or 'Raw'
stimulusAmplitudeIndex = 7;
noStimulusAmplitudeIndex = 1;

% Load negative time so baseline is measured independently of the fit.
% here folllowing whatever's there in
% displayAllChannelsICMSSingleElectrode.m
loadedTimeRange = [-0.5, 1.5];               % [-0.20, 1.30];
baselineTimeRange = [-0.7, -0.2];       %[-0.25, -0.05], [-.7, -.2];    %[-0.20, -0.02]; seems to contain some spikes 
analysisTimeRange = [-0.5, 1.50];      %[0.75, 1.25]   [0, 1.30];  % for now, analysisTimeRange = loadedTimeRange
stimTimeRange = [0.75, 1.25];


%% 2. Editable fitting and display settings

maximumShiftSeconds = 0.002;        % +/- 2 ms, 6 ms
fitSearchRateHz = 30000;             % Full LFP; reduced scoring for Raw

% Set true to fit and report every no-stimulation trial before opening UI.
runAllTrialValidation = false;

% initialNoStimTrial = 42;

spectrogramWindowSeconds = 0.10;
spectrogramOverlapFraction = 0.90;
spectrogramDynamicRangeDb = 80;


%% 3. Confirm required MATLAB function

if exist('lsqcurvefit', 'file') ~= 2
    error([ ...
        'This file requires lsqcurvefit from MATLAB Optimization ' ...
        'Toolbox. Install or license Optimization Toolbox, then rerun.']);
end

optimizationToolboxInfo = ver('optim');

if ~isempty(optimizationToolboxInfo)
    fprintf('Optimization Toolbox version: %s\n', ...
        optimizationToolboxInfo(1).Version);
end


%% 4. Load stimulation and no-stimulation data

if strcmp(dataSource, 'Raw')
    metaInfoFileName = 'rawInfo.mat';
else
    metaInfoFileName = 'lfpInfo.mat';
end

dataFile = fullfile( ...
    folderSourceString, 'data', subjectName, gridType, ...
    expDate, protocolName, 'segmentedData', dataSource, ...
    ['elec' num2str(electrodeNumber) '.mat']);

infoFile = fullfile( ...
    folderSourceString, 'data', subjectName, gridType, ...
    expDate, protocolName, 'segmentedData', dataSource, ...
    metaInfoFileName);

parameterFile = fullfile( ...
    folderSourceString, 'data', subjectName, gridType, ...
    expDate, protocolName, 'extractedData', ...
    'parameterCombinations.mat');

dataFileContents = load(dataFile);
infoFileContents = load(infoFile);
parameterFileContents = load(parameterFile);

parameterCombinations = ...
    parameterFileContents.parameterCombinations;

if strcmp(dataSource, 'Raw')
    completeTime = infoFileContents.timeValsRaw;
else
    completeTime = infoFileContents.timeVals;
end

completeTime = completeTime(:).';

loadedSampleMask = ...
    completeTime >= loadedTimeRange(1) & ...
    completeTime <= loadedTimeRange(2);

loadedTime = completeTime(loadedSampleMask);

stimulusTrialIndices = ...
    parameterCombinations{ ...
    stimulusAmplitudeIndex,1,1,5,5,4};

noStimulusTrialIndices = ...
    parameterCombinations{ ...
    noStimulusAmplitudeIndex,1,1,5,5,4};

if strcmp(dataSource, 'Raw')
    loadedStimData = double(dataFileContents.rawData( ...
        stimulusTrialIndices, loadedSampleMask));
    loadedNoStimData = double(dataFileContents.rawData( ...
        noStimulusTrialIndices, loadedSampleMask));
else
    loadedStimData = double(dataFileContents.analogData( ...
        stimulusTrialIndices, loadedSampleMask));
    loadedNoStimData = double(dataFileContents.analogData( ...
        noStimulusTrialIndices, loadedSampleMask));
end

samplingRateHz = 1 / median(diff(loadedTime));

fprintf('Data source                 : %s\n', dataSource);
fprintf('Sampling rate              : %.3f Hz\n', samplingRateHz);
fprintf('Number of stimulation rows : %d\n', size(loadedStimData,1));
fprintf('Number of no-stim rows     : %d\n', size(loadedNoStimData,1));

%% 5.1.1 Data alignment before baseline correction, based on the 1st spike artifact onset

% [dataStimStartPosns, alignedData] = alignStimStartPosns(dataFileContents.rawData( ...
%         stimulusTrialIndices, :), completeTime, baselineTimeRange);

%% 5.1 Independent pre-stimulation baseline correction
%
% Each row has its own pre-stimulation median subtracted. Baseline is not
% estimated again by lsqcurvefit, so the recovered no-stimulation mean is
% not deliberately forced to zero.

baselineMask = ...
    loadedTime >= baselineTimeRange(1) & ...
    loadedTime <= baselineTimeRange(2);

if nnz(baselineMask) < 5
    error('Baseline interval contains fewer than five samples.');
end

loadedStimData = subtractRowBaseline( ...
    loadedStimData, baselineMask);

loadedNoStimData = subtractRowBaseline( ...
    loadedNoStimData, baselineMask);

analysisMask = ...       
    loadedTime >= analysisTimeRange(1) & ...
    loadedTime <= analysisTimeRange(2);

time = loadedTime(analysisMask);   
time = time(:).';

dataStim = loadedStimData(:,analysisMask);
dataNoStim = loadedNoStimData(:,analysisMask);

stimMask = ...                          
    loadedTime >= stimTimeRange(1) & ...
    loadedTime <= stimTimeRange(2);

stimTime = loadedTime(stimMask);
stimTime = stimTime(:).';                  % not used anywhere


%% 5.2 Aligning of signals

% the 1st spike of each waveform is aligned using the getStimStartPositions
% & alignStimStartPositions functions
[dataStimStartPosns, alignedData] = alignStimStartPosns(loadedStimData, loadedTime, baselineTimeRange);
dataStim = alignedData(:, analysisMask);


%% 6. One complete data-derived artifact template

medianArtifact = median(dataStim, 1, 'omitnan');  % median(dataStim, 1, 'omitnan'); mean(dataStim, 1); 
%% 6.2 Plot median artifact if required
figure; plot(time, medianArtifact, 'r', 'LineWidth', 1.4); title('median artifact')


%% 7. lsqcurvefit configuration

fitOptions = optimoptions( ...
    'lsqcurvefit', ...
    'Algorithm', 'trust-region-reflective', ...
    'Display', 'off', ...
    'FiniteDifferenceType', 'central', ...
    'TypicalX', [1; 0.001], ...
    'MaxFunctionEvaluations', 500, ...
    'FunctionTolerance', 1e-10, ...
    'StepTolerance', 1e-10, ...
    'OptimalityTolerance', 1e-10);

initialParameters = [1; 0];         % [gain; shiftSeconds]
lowerBounds = [0; -maximumShiftSeconds];
upperBounds = [Inf; maximumShiftSeconds];

% Every possible shift must remain inside the recorded template.
commonFitMask = ...
    time >= time(1) + maximumShiftSeconds & ...
    time <= time(end) - maximumShiftSeconds & ...
    isfinite(medianArtifact);

fitIndices = find(commonFitMask);

fitStride = max(1, round(samplingRateHz / fitSearchRateHz));
fitIndices = fitIndices(1:fitStride:end);

if numel(fitIndices) < 20
    error('Too few valid samples are available for lsqcurvefit.');
end

fitTime = time(fitIndices);


%% 8. Optional validation over all no-stimulation trials

if runAllTrialValidation
    fprintf('\nValidating all no-stimulation trials with lsqcurvefit...\n');

    validationResults = validateAllTrials( ...
        dataNoStim, time, medianArtifact, ...
        fitIndices, fitTime, ...
        initialParameters, lowerBounds, upperBounds, ...
        fitOptions);

    printValidationSummary(validationResults);
else
    validationResults = table();
end


%% 9. clean up all the signals corresponding to the chosen electrode

numberOfNoStimTrials = size(dataNoStim,1);
numberOfStimTrials = size(dataStim, 1);

cleanedSignals = zeros(numberOfStimTrials, length(analysisMask));

fitMSEflag = false;
fitMSE = [];
fittedTrials = [];
percentageTrials = 10;     % 1, 2, 3, 5, 10, 30, 50, 100

for idx=1:numberOfStimTrials

    % cleanedTrial = fitArtifactTemplate( ...
    %     time, dataStim(idx, :), medianArtifact, samplingRateHz, ...
    %     fitIndices, fitTime, ...
    %     initialParameters, lowerBounds, upperBounds, fitOptions, ...
    %     spectrogramWindowSeconds, spectrogramOverlapFraction, ...
    %     spectrogramDynamicRangeDb, idx);

    fitResult = fitFractionOfTrialsMedianCurve( ...
        dataStim(idx, :), time, dataStim, ...
        fitIndices, fitTime, ...
        initialParameters, lowerBounds, upperBounds, fitOptions, ...
        fitMSEflag, fitMSE, fittedTrials, idx, percentageTrials);

    fittedArtifact = fitResult.FittedArtifact;
    cleanedTrial = dataStim(idx, :) - fittedArtifact;

    cleanedSignals(idx, :) = cleanedTrial;
end


%% 10. plot \delta spectrograms (b/w baseLine and stimRange), for the noStimTrials & stimTrials side by side
psdTFdataNoStim = getGRF(dataNoStim, time, baselineTimeRange, stimTimeRange);
psdTFdataStim   = getGRF(cleanedSignals, time, baselineTimeRange, stimTimeRange);

%% 10.1 Plot deltaTF and deltaPSD: no-stim vs artifact-removed stim

plotAvgTFs(psdTFdataNoStim, psdTFdataStim, stimTimeRange, spectrogramDynamicRangeDb);


%% Local functions

function correctedData = subtractRowBaseline(data, baselineMask)
% Subtract the pre-stimulation median independently from every row.

    rowBaselines = median( ...
        data(:,baselineMask), 2, 'omitnan');

    correctedData = data - rowBaselines;
end


function modelValues = shiftedTemplateModel( ...
    parameters, queryTime, templateTime, artifactTemplate)
% Evaluate gain * template(time - shift).

    gain = parameters(1);
    shiftSeconds = parameters(2);

    shiftedTemplate = interp1( ...
        templateTime(:), artifactTemplate(:), ...
        queryTime(:) - shiftSeconds, ...
        'linear');

    modelValues = gain * shiftedTemplate;
end


function fitResult = fitOneSummedCurve( ...
    summedCurve, time, artifactTemplate, ...
    fitIndices, fitTime, ...
    initialParameters, lowerBounds, upperBounds, fitOptions)
% Fit one gain and one time shift with MATLAB lsqcurvefit.

    observedAtFitSamples = summedCurve(fitIndices).';

    modelFunction = @(parameters, queryTime) ...
        shiftedTemplateModel( ...
        parameters, queryTime, time, artifactTemplate);

    [parameters, residualSumOfSquares, solverResidual, ...
        exitFlag, solverOutput] = lsqcurvefit( ...
        modelFunction, ...
        initialParameters, ...
        fitTime(:), ...
        observedAtFitSamples, ...
        lowerBounds, ...
        upperBounds, ...
        fitOptions);

    shiftedTime = time - parameters(2);

    fittedArtifact = interp1( ...
        time(:), ...
        artifactTemplate(:), ...
        shiftedTime(:), ...
        'linear', ...
        0).';
    
    fittedArtifact = parameters(1) * fittedArtifact;

    fitResult = struct( ...
        'Gain', parameters(1), ...
        'ShiftSeconds', parameters(2), ...
        'FittedArtifact', fittedArtifact, ...
        'ResidualSumOfSquares', residualSumOfSquares, ...
        'FitMSE', mean(solverResidual.^2), ...
        'ExitFlag', exitFlag, ...
        'SolverOutput', solverOutput);
end


function validationResults = validateAllTrials( ...     
    dataNoStim, time, artifactTemplate, ...
    fitIndices, fitTime, ...
    initialParameters, lowerBounds, upperBounds, fitOptions)
% Add every known no-stimulation trial, fit, and measure its recovery.

    numberOfTrials = size(dataNoStim,1);

    gain = nan(numberOfTrials,1);
    shiftMilliseconds = nan(numberOfTrials,1);
    fitMSE = nan(numberOfTrials,1);
    recoveryRMSE = nan(numberOfTrials,1);
    recoveryCorrelation = nan(numberOfTrials,1);
    meanRecoveryError = nan(numberOfTrials,1);
    exitFlag = nan(numberOfTrials,1);
    functionEvaluations = nan(numberOfTrials,1);

    for trial = 1:numberOfTrials
        trueNoStim = dataNoStim(trial,:);
        summedCurve = artifactTemplate + trueNoStim;

        fitResult = fitOneSummedCurve( ...
            summedCurve, time, artifactTemplate, ...
            fitIndices, fitTime, ...
            initialParameters, lowerBounds, upperBounds, ...
            fitOptions);

        recoveredNoStim = ...
            summedCurve - fitResult.FittedArtifact;

        valid = ...
            isfinite(recoveredNoStim) & ...
            isfinite(trueNoStim);

        recoveryError = ...
            recoveredNoStim(valid) - trueNoStim(valid);

        correlationMatrix = corrcoef( ...
            recoveredNoStim(valid), trueNoStim(valid));

        if all(size(correlationMatrix) == [2,2])
            currentCorrelation = correlationMatrix(1,2);
        else
            currentCorrelation = NaN;
        end

        gain(trial) = fitResult.Gain;
        shiftMilliseconds(trial) = ...
            1000 * fitResult.ShiftSeconds;
        fitMSE(trial) = fitResult.FitMSE;
        recoveryRMSE(trial) = ...
            sqrt(mean(recoveryError.^2));
        recoveryCorrelation(trial) = currentCorrelation;
        meanRecoveryError(trial) = mean(recoveryError);
        exitFlag(trial) = fitResult.ExitFlag;
        functionEvaluations(trial) = ...
            fitResult.SolverOutput.funcCount;
    end

    validationResults = table( ...
        (1:numberOfTrials).', ...
        gain, shiftMilliseconds, fitMSE, ...
        recoveryRMSE, recoveryCorrelation, ...
        meanRecoveryError, exitFlag, functionEvaluations, ...
        'VariableNames', { ...
        'NoStimTrial', ...
        'Gain', ...
        'ShiftMilliseconds', ...
        'FitMSE', ...
        'RecoveryRMSE', ...
        'RecoveryCorrelation', ...
        'MeanRecoveryError', ...
        'ExitFlag', ...
        'FunctionEvaluations'});
end


function printValidationSummary(results)
% Print reproducible summary statistics and best/worst trial numbers.

    numberOfTrials = height(results);

    sortedRMSE = sort(results.RecoveryRMSE);
    percentile95Index = min( ...
        numberOfTrials, max(1, ceil(0.95 * numberOfTrials)));

    sortedCorrelation = sort(results.RecoveryCorrelation);
    percentile05Index = min( ...
        numberOfTrials, max(1, ceil(0.05 * numberOfTrials)));

    fprintf('\n--- lsqcurvefit validation summary ---\n');
    fprintf('Trials                         : %d\n', ...
        numberOfTrials);
    fprintf('Positive solver exit flags     : %d/%d\n', ...
        nnz(results.ExitFlag > 0), numberOfTrials);
    fprintf('Median recovery RMSE           : %.6g\n', ...
        median(results.RecoveryRMSE, 'omitnan'));
    fprintf('Approximate 95th percentile RMSE: %.6g\n', ...
        sortedRMSE(percentile95Index));
    fprintf('Maximum recovery RMSE          : %.6g\n', ...
        max(results.RecoveryRMSE));
    fprintf('Median recovery correlation    : %.6f\n', ...
        median(results.RecoveryCorrelation, 'omitnan'));
    fprintf('Approximate 5th percentile corr: %.6f\n', ...
        sortedCorrelation(percentile05Index));
    fprintf('Minimum recovery correlation   : %.6f\n', ...
        min(results.RecoveryCorrelation));

    [~, bestOrder] = sort(results.RecoveryRMSE, 'ascend');
    [~, worstOrder] = sort(results.RecoveryRMSE, 'descend');

    numberToPrint = min(5, numberOfTrials);

    fprintf('\nBest %d trials by recovery RMSE:\n', numberToPrint);
    disp(results(bestOrder(1:numberToPrint), ...
        {'NoStimTrial','RecoveryRMSE', ...
        'RecoveryCorrelation','Gain','ShiftMilliseconds'}));

    fprintf('Worst %d trials by recovery RMSE:\n', numberToPrint);
    disp(results(worstOrder(1:numberToPrint), ...
        {'NoStimTrial','RecoveryRMSE', ...
        'RecoveryCorrelation','Gain','ShiftMilliseconds'}));
end


function fitResult = fitFractionOfTrialsMedianCurve( ...
    summedCurve, time, stimTrials, ...
    fitIndices, fitTime, ...
    initialParameters, lowerBounds, upperBounds, fitOptions,...
    fitMSEflag, fitMSE, fittedTrials, currentTrial, percentageTrials)             %% how to make sure to recalculate each time new trial is given
% Fit one gain and one time shift with MATLAB lsqcurvefit.

    observedAtFitSamples = summedCurve(fitIndices).';
    numStimTrials = size(stimTrials, 1);

    if ~fitMSEflag
        fitMSE = inf(1, numStimTrials);
        fittedTrials = zeros(size(stimTrials));
        fittedTrials(currentTrial, :) = stimTrials(currentTrial, :);
    
        for i = 1:numStimTrials
            if i == currentTrial
                continue
            end
            modelFunction = @(parameters, queryTime) ...
                shiftedTemplateModel( ...
                parameters, queryTime, time, stimTrials(i, :));
    
            [parameters, residualSumOfSquares, solverResidual, ...
                exitFlag, ~] = lsqcurvefit( ...
                modelFunction, ...
                initialParameters, ...
                fitTime(:), ...
                observedAtFitSamples, ...
                lowerBounds, ...
                upperBounds, ...
                fitOptions);

            shiftedTime = time - parameters(2);

            fittedCurve = interp1( ...
                time(:), ...
                stimTrials(i, :), ...
                shiftedTime(:), ...
                'linear', ...
                0).';
            
            fittedTrials(i, :) = parameters(1) * fittedCurve;
    
            fitMSE(i) = mean(solverResidual.^2);
        end
        fitMSEflag = true;
    end

        % scaledShiftedTrial = shiftedTemplateModel( ...        %% if use corr to do the ranking
        %     parameters, time(:), time, stimTrials(i, :)).';
        % 
        % r = xcorr(summedCurve, scaledShiftedTrial, 'normalized'); 
        % corrVals(i) = max(r);

    if percentageTrials == 101           % 101 if you want to 1st fit each trial to currentTrial & then take median of those fitted trials
        yMedian = median(stimTrials, 1, 'omitnan');

    else
        k = round((numStimTrials - 1)*percentageTrials/100);
        k = max(k, 1);           % at least 1 trial is chosen
    
        [best_mse_vals, best_mse_indices] = mink(fitMSE, k);
        best_mse_indices = [best_mse_indices, currentTrial];       % do this if also want to take current trial in the median

        yMedian = median(fittedTrials(best_mse_indices, :), 1, 'omitnan');
    end

    modelFunction = @(parameters, queryTime) ...
        shiftedTemplateModel( ...
        parameters, queryTime, time, yMedian);

    [parameters, residualSumOfSquares, solverResidual, ...
        exitFlag, solverOutput] = lsqcurvefit( ...
        modelFunction, ...
        initialParameters, ...
        fitTime(:), ...
        observedAtFitSamples, ...
        lowerBounds, ...
        upperBounds, ...
        fitOptions);

    shiftedTime = time - parameters(2);

    fittedArtifact = interp1( ...
        time(:), ...
        yMedian(:), ...
        shiftedTime(:), ...
        'linear', ...
        0).';
    
    fittedArtifact = parameters(1) * fittedArtifact;

    fitResult = struct( ...
        'Gain', parameters(1), ...
        'ShiftSeconds', parameters(2), ...
        'FittedArtifact', fittedArtifact, ...
        'ResidualSumOfSquares', residualSumOfSquares, ...
        'FitMSE', mean(solverResidual.^2), ...
        'ExitFlag', exitFlag, ...
        'SolverOutput', solverOutput, ...
        'FitMSEflag', fitMSEflag, ...
        'FitMSEarray', fitMSE, ...
        'fittedTrials', fittedTrials);

    fprintf('trial %d done\n', currentTrial);
end


function recoveredStim = fitArtifactTemplate( ...
    time, stimCurve, artifactTemplate, samplingRateHz, ...     % fits stimTrial (stimCurve) to an artifact template, which is supplied
    fitIndices, fitTime, ...
    initialParameters, lowerBounds, upperBounds, fitOptions, ...
    spectrogramWindowSeconds, spectrogramOverlapFraction, ...
    spectrogramDynamicRangeDb, currentTrial)

    fitTimer = tic;

    fitResult = fitOneSummedCurve( ...
        stimCurve, time, artifactTemplate, ...
        fitIndices, fitTime, ...
        initialParameters, lowerBounds, upperBounds, ...
        fitOptions);

    elapsedSeconds = toc(fitTimer);

    fittedArtifact = fitResult.FittedArtifact;
    recoveredStim = stimCurve - fittedArtifact;

    valid = ...
        isfinite(fittedArtifact) & ...
        isfinite(recoveredStim);

    fprintf([ ...
        '\nlsqcurvefit dataStim trial %d\n' ...
        'gain %.6f | shift %.6f ms\n' ...
        'exit flag %d | function evaluations %d\n' ...
        'fitted in %.3fs\n\n'], ...
        currentTrial, ...
        fitResult.Gain, ...
        1000*fitResult.ShiftSeconds, ...
        fitResult.ExitFlag, ...
        fitResult.SolverOutput.funcCount, ...
        elapsedSeconds);

end


function plotAvgTFs(psdTFdataNoStim, psdTFdataStim, stimTimeRange, spectrogramDynamicRangeDb)

    figure('Color', 'w', 'Position', [100 100 1200 800]);
    colormap jet;
    
    tiledlayout(2,2, 'TileSpacing', 'compact', 'Padding', 'compact');
    
    % -------------------- Top left: deltaTF - noStim --------------------
    nexttile;
    
    imagesc(psdTFdataNoStim.timeTF, ...
            psdTFdataNoStim.freqTF, ...
            psdTFdataNoStim.deltaTF.');
    
    axis xy;
    xline(stimTimeRange(1), 'k--', 'LineWidth', 1);
    xline(stimTimeRange(2), 'k--', 'LineWidth', 1);
    
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
    title('No-stim trials: \DeltaTF');
    
    cb = colorbar;
    cb.Label.String = '\Delta Power (dB)';
    
    clim([-spectrogramDynamicRangeDb/2, spectrogramDynamicRangeDb/2]);
    
    
    % -------------------- Top right: deltaTF - stim --------------------
    nexttile;
    
    imagesc(psdTFdataStim.timeTF, ...
            psdTFdataStim.freqTF, ...
            psdTFdataStim.deltaTF.');
    
    axis xy;
    xline(stimTimeRange(1), 'k--', 'LineWidth', 1);
    xline(stimTimeRange(2), 'k--', 'LineWidth', 1);
    
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
    title('Artifact-removed stim trials: \DeltaTF');
    
    cb = colorbar;
    cb.Label.String = '\Delta Power (dB)';
    
    clim([-spectrogramDynamicRangeDb/2, spectrogramDynamicRangeDb/2]);
    
    
    % -------------------- Bottom left: deltaPSD - noStim --------------------
    nexttile;
    
    plot(psdTFdataNoStim.freqST, ...
         psdTFdataNoStim.deltaPSD, ...
         'LineWidth', 1.5);
    
    xlabel('Frequency (Hz)');
    ylabel('\Delta Power (dB)');
    title('No-stim trials: \DeltaPSD');
    
    xlim([0 250]);    % [0 250] [0 100]
    grid on;
    
    
    % -------------------- Bottom right: deltaPSD - stim --------------------
    nexttile;
    
    plot(psdTFdataStim.freqST, ...
         psdTFdataStim.deltaPSD, ...
         'LineWidth', 1.5);
    
    xlabel('Frequency (Hz)');
    ylabel('\Delta Power (dB)');
    title('Artifact-removed stim trials: \DeltaPSD');
    
    xlim([0 250]);
    grid on;

end