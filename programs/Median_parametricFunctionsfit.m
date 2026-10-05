% % 
% Aniket Mandal, IISc
% ver 1.0.0- 21st Aug '26
% Trying to fit different functions to the median artifact/portion of the median artifact

%% Data from previous experiences we can use
% for elec1, trial 42, baseline-corrected, aligned raw (30 KHz) signal -->
%   post-cleaning spike locations-
% 0.0417 .0481
% .0917 .098
% .1416 .1467
% .1916 .1978
% .2415 .2484
% .2915 .3
% .3413 .3423

% %  for fitting curve to the raw data (30 KHz) median itself
% sigmoid ranges->
% .0426 .0502

% % for elec42, trial 106 differs a lot from median

%% Single-template fitting with MATLAB lsqcurvefit
%
% PURPOSE
%   This is a new, standalone, traceable implementation. It does not call
%   the custom grid-search or slow/fast fitting code in the other files.
%
% MODEL
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
electrodeNumber = 1;   % 1, 42

dataSource = 'Raw';                 % 'LFP' or 'Raw'
stimulusAmplitudeIndex = 7;
noStimulusAmplitudeIndex = 1;

% Load negative time so baseline is measured independently of the fit.
loadedTimeRange = [-0.20, 1.30];
baselineTimeRange = [-0.25, -0.05];    %[-0.20, -0.02]; seems to contain some spikes 
analysisTimeRange = [-0.05, 1.30];        % [0, 1.30]  [-0.20, 1.30];


%% 2. Editable fitting and display settings

maximumShiftSeconds = 0.002;        % +/- 2 ms, 6 ms
fitSearchRateHz = 30000;             % Full LFP; reduced scoring for Raw

% Set true to fit and report every no-stimulation trial before opening UI.
runAllTrialValidation = false;

initialNoStimTrial = 42;

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
fprintf('Processing elec%d\n', electrodeNumber);

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


%% 5.2 Aligning of signals

% the 1st spike of each waveform is aligned using the getStimStartPositions
% & alignStimStartPositions functions
[dataStimStartPosns, alignedData] = alignStimStartPosns(loadedStimData, loadedTime, baselineTimeRange);
dataStim = alignedData(:, analysisMask);


%% 6. One complete data-derived artifact template

medianArtifact = median(dataStim, 1, 'omitnan');  % median(dataStim, 1, 'omitnan'); mean(dataStim, 1); 
%% 6.2 Plot median artifact if required
figure; plot(time, medianArtifact, 'r', 'LineWidth', 1.4); title('median artifact')


% % some useful median artifact (post baseline([-0.7 -0.2]) correction and aligning) properties for elec1, \muStim amp=7


%%% for LFP data median (2 KHz)

% slow moving artifact locations
% [-.002 0.045]; [0.048 0.0955]; [0.098 0.1455]; [0.148 0.195]; [0.1975 0.245]; [0.2475 0.295]; [0.2975 0.3455]
% spiky artifact locations
% [-.0045, -0.002]; [0.045, 0.048]; [0.0955 0.098]; [0.1455 0.148]; [0.195 0.1975]; [0.245 0.2475]; [0.295 0.2975]; [0.3455 0.3485]


%%% for raw data Median (30 KHz)

% slow moving artifact locations
% [-.00636 0.04036]; [0.04356 0.0904]; [0.09383 0.14013]; [0.14376 0.19006]; [0.19356 0.23996]; [0.24356 0.2902]; [0.29336 0.34003]
% spiky artifact locations
% [-.00826, -0.00636]; [0.04036, 0.04356]; [0.0904 0.09383]; [0.14013 0.14376]; [0.19006 0.19356]; [0.23996 0.24356]; [0.2902 0.29336]; [0.34003 0.3448]


%% 7. store the individual slow-moving artifact slices

artifactSlices = cell(1, 7);
timeSlices = cell(1, 7);

artifactSlicesLocations = [[-.00636 0.04036]; [0.04356 0.0904]; [0.09383 0.14013]; [0.14376 0.19006]; [0.19356 0.23996]; [0.24356 0.2902]; [0.29336 0.34003]];

for i=1:7
    artifactSlices{i} = medianArtifact(find(time >= artifactSlicesLocations(i, 1), 1):find(time >= artifactSlicesLocations(i, 2), 1));
    timeSlices{i} = time(find(time >= artifactSlicesLocations(i, 1), 1):find(time >= artifactSlicesLocations(i, 2), 1));  % artifactSlicesLocations(i, 1):artifactSlicesLocations(i, 2)
end


%% 8. lsqcurvefit configuration

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


%% 9. Launch the median curve-fitting explorer, which tries to fit different parametric function forms to the median

fitMethod = 'poly';           % 'spline', 'poly'

fitWholeMedian = true;

if fitWholeMedian

    spectrogramWindowSeconds = 0.10;
    spectrogramOverlapFraction = 0.90;

    launchMedianFitExplorer( ...
        time, ...
        medianArtifact, ...
        fitMethod, ...
        samplingRateHz, ...
        spectrogramWindowSeconds, ...
        spectrogramOverlapFraction, ...
        spectrogramDynamicRangeDb);

end


%% 10. Fit the functions to different individual slices of the whole artifact train

fitMethod = 'poly';           % 'spline', 'poly'
spectrogramWindowSeconds = 0.01;                %% something wrong with the specgram plottings, have to figure out
spectrogramOverlapFraction = 0.90;

idx = 2;

launchMedianFitExplorer( ...
        timeSlices{idx}, ...
        artifactSlices{idx}, ...
        fitMethod, ...
        samplingRateHz, ...
        spectrogramWindowSeconds, ...
        spectrogramOverlapFraction, ...
        spectrogramDynamicRangeDb);


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

    fittedArtifact = shiftedTemplateModel( ...
        parameters, time(:), time, artifactTemplate).';

    fitResult = struct( ...
        'Gain', parameters(1), ...
        'ShiftSeconds', parameters(2), ...
        'FittedArtifact', fittedArtifact, ...
        'ResidualSumOfSquares', residualSumOfSquares, ...
        'FitMSE', mean(solverResidual.^2), ...
        'ExitFlag', exitFlag, ...
        'SolverOutput', solverOutput);
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

    if percentageTrials == 100           % 101 if you want to 1st fit each trial to currentTrial & then take median of those fitted trials
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

    fittedArtifact = shiftedTemplateModel( ...
        parameters, time(:), time, yMedian).';

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
end


function formatSpectrogramAxis( ...
    axisHandle, maximumFrequency, colorLimits, titleText)
% Apply identical frequency and color ranges to a spectrogram axis.

    axis(axisHandle, 'xy');
    ylim(axisHandle, [0,maximumFrequency]);
    caxis(axisHandle, colorLimits);
    xlabel(axisHandle, 'Time (s)');
    ylabel(axisHandle, 'Frequency (Hz)');
    title(axisHandle, titleText);
end


function [powerDb, frequency, experimentalTime] = ...
    calculateSpectrogramDb( ...
    signal, time, samplingRateHz, ...
    windowSeconds, overlapFraction)
% Calculate a mean-removed Hann-window spectrogram in decibels.

    signal = signal(:).';
    signal = signal - mean(signal, 'omitnan');

    windowLength = min( ...
        round(windowSeconds * samplingRateHz), ...
        length(signal) - 1);
    windowLength = max(windowLength, 16);

    if windowLength >= length(signal)
        windowLength = length(signal) - 1;
    end

    overlapLength = min( ...
        round(overlapFraction * windowLength), ...
        windowLength - 1);

    fftLength = 2^nextpow2(windowLength);

    windowIndex = (0:windowLength-1).';
    hannWindow = 0.5 - 0.5*cos( ...
        2*pi*windowIndex/windowLength);

    [transform, frequency, relativeTime] = spectrogram( ...
        signal, hannWindow, overlapLength, ...
        fftLength, samplingRateHz);

    powerDb = 10*log10(abs(transform).^2 + eps);
    experimentalTime = relativeTime + time(1);
end


%% Interactive explorer function

function launchMedianFitExplorer( ...
    time, medianArtifact, fitMethod, samplingRateHz, ...
    spectrogramWindowSeconds, spectrogramOverlapFraction, ...
    spectrogramDynamicRangeDb)

% Interactive explorer for fitting different function classes to the
% complete median artifact.
%
% Supported methods:
%   1. Polynomial
%   2. Smoothing spline
%   3. Cubic spline interpolation
%   4. PCHIP interpolation
% %%%%%%%%%%%%%%%%%%%%% try SG filter %%%%%%%%%%%%%%%%%%%%%%
%
% The explorer displays:
%
%   Row 1: original median and fitted median
%   Row 2: spectrogram of fitted median
%
% Polynomial order can be changed interactively.
%
% IMPORTANT:
% Polynomial fitting uses a scaled time variable in [-1,1]. This is
% important for numerical stability, especially for high polynomial orders.


    % ---------------------------------------------------------------
    % Internal state
    % ---------------------------------------------------------------

    time = time(:).';
    originalMedian = medianArtifact(:).';

    maximumFrequency = samplingRateHz / 2;
    maximumSpecgramColorbarValue = 150;

    % Default settings
    if nargin < 3 || isempty(fitMethod)
        fitMethod = 'spline';
    end

    polynomialOrder = 5;

    % Smoothing parameter:
    %
    % 1       -> almost interpolation
    % 0       -> maximum smoothing
    %
    % The exact behaviour is determined by MATLAB's smoothing-spline
    % implementation.
    smoothingParameter = 0.1;     % 0.99

    fittedMedian = originalMedian;


    % % ---------------------------------------------------------------
    % Figure
    % ---------------------------------------------------------------

    fig = uifigure( ...
        'Name', 'Median Artifact Function Fit Explorer', ...
        'Position', [100, 60, 1500, 900]);


    outerLayout = uigridlayout(fig, [2,1]);

    outerLayout.RowHeight = {110, '1x'};
    outerLayout.Padding = [8 8 8 8];


    % ---------------------------------------------------------------
    % Controls
    % ---------------------------------------------------------------
    
    controlLayout = uigridlayout(outerLayout, [2,9]);
    
    controlLayout.Layout.Row = 1;
    
    controlLayout.RowHeight = {35,35};
    
    controlLayout.ColumnWidth = ...
        {160,150,120,120,140,'1x',130,110,110};
    
    controlLayout.Padding = [5 5 5 5];
    
    
    % ---------------------------------------------------------------
    % Row 1
    % ---------------------------------------------------------------
    
    fitFunctionLabel = uilabel(controlLayout, ...
        'Text', 'Fit function:', ...
        'HorizontalAlignment', 'right');
    
    fitFunctionLabel.Layout.Row = 1;
    fitFunctionLabel.Layout.Column = 1;
    
    
    fitFunctionDropDown = uidropdown(controlLayout, ...
        'Items', { ...
            'Polynomial', ...
            'Smoothing spline', ...
            'Cubic spline', ...
            'PCHIP' ...
            'Multi-exponentials'}, ...
        'Value', methodToDisplayName(fitMethod));
    
    fitFunctionDropDown.Layout.Row = 1;
    fitFunctionDropDown.Layout.Column = 2;
    
    
    polynomialOrderLabel = uilabel(controlLayout, ...
        'Text', 'Polynomial order:', ...
        'HorizontalAlignment', 'right');
    
    polynomialOrderLabel.Layout.Row = 1;
    polynomialOrderLabel.Layout.Column = 3;
    
    
    polynomialOrderField = uieditfield( ...
        controlLayout, 'numeric', ...
        'Value', polynomialOrder, ...
        'Limits', [0 5000], ...
        'RoundFractionalValues', true);
    
    polynomialOrderField.Layout.Row = 1;
    polynomialOrderField.Layout.Column = 4;
    
    
    smoothingLabel = uilabel(controlLayout, ...
        'Text', 'Smoothing:', ...
        'HorizontalAlignment', 'right');
    
    smoothingLabel.Layout.Row = 1;
    smoothingLabel.Layout.Column = 5;
    
    
    smoothingField = uieditfield( ...
        controlLayout, 'numeric', ...
        'Value', smoothingParameter, ...
        'Limits', [0 1]);
    
    smoothingField.Layout.Row = 1;
    smoothingField.Layout.Column = 6;

    numberExponentialsLabel = uilabel(controlLayout, ...
        'Text', 'No. exponentials:', ...
        'HorizontalAlignment', 'right');
    
    numberExponentialsLabel.Layout.Row = 1;
    numberExponentialsLabel.Layout.Column = 7;
    
    numberExponentialsField = uieditfield( ...
        controlLayout, 'numeric', ...
        'Value', 2, ...
        'Limits', [1 500], ...
        'RoundFractionalValues', true);
    
    numberExponentialsField.Layout.Row = 1;
    numberExponentialsField.Layout.Column = 8;

    closeButton = uibutton(controlLayout, ...
        'push', ...
        'Text', 'Close', ...
        'ButtonPushedFcn', @(~,~) close(fig));
    
    closeButton.Layout.Row = 1;
    closeButton.Layout.Column = 9;
    
    % ---------------------------------------------------------------
    % Row 2
    % ---------------------------------------------------------------
    
    maximumFrequencyLabel = uilabel(controlLayout, ...
        'Text', 'Spectrogram max Hz:', ...
        'HorizontalAlignment', 'right');
    
    maximumFrequencyLabel.Layout.Row = 2;
    maximumFrequencyLabel.Layout.Column = 1;
    
    
    maximumFrequencyField = uieditfield( ...
        controlLayout, 'numeric', ...
        'Value', maximumFrequency, ...
        'Limits', [1 maximumFrequency]);
    
    maximumFrequencyField.Layout.Row = 2;
    maximumFrequencyField.Layout.Column = 2;
    
    
    statusLabel = uilabel(controlLayout, ...
        'Text', 'Ready', ...
        'HorizontalAlignment', 'left');
    
    statusLabel.Layout.Row = 2;
    statusLabel.Layout.Column = [3 4];
    
    
    fitInfoLabel = uilabel(controlLayout, ...
        'Text', '', ...
        'HorizontalAlignment', 'right');
    
    fitInfoLabel.Layout.Row = 2;
    fitInfoLabel.Layout.Column = 5;


    cbar1Label = uilabel(controlLayout, ...
        'Text', 'Left cbar max dB:', ...
        'HorizontalAlignment', 'right');
    
    cbar1Label.Layout.Row = 2;
    cbar1Label.Layout.Column = 6;
    
    
    maximumCbar1Field = uieditfield( ...
        controlLayout, 'numeric', ...
        'AllowEmpty','on', ...
        'Value', [], ...
        'Limits', [-10 maximumSpecgramColorbarValue]);
    
    maximumCbar1Field.Layout.Row = 2;
    maximumCbar1Field.Layout.Column = 7;


    cbar2Label = uilabel(controlLayout, ...
        'Text', 'Right cbar max dB:', ...
        'HorizontalAlignment', 'right');
    
    cbar2Label.Layout.Row = 2;
    cbar2Label.Layout.Column = 8;
    
    
    maximumCbar2Field = uieditfield( ...
        controlLayout, 'numeric', ...
        'AllowEmpty','on', ...
        'Value', [], ...
        'Limits', [-10 maximumSpecgramColorbarValue]);
    
    maximumCbar2Field.Layout.Row = 2;
    maximumCbar2Field.Layout.Column = 9;

    % maximumSpecgramColorbarValue


    % ---------------------------------------------------------------
    % Plot layout
    % ---------------------------------------------------------------

    plotLayout = uigridlayout(outerLayout, [2,2]);

    plotLayout.Layout.Row = 2;
    
    plotLayout.RowHeight = {'1x','1x'};
    plotLayout.ColumnWidth = {'1x','1x'};
    
    plotLayout.Padding = [5 5 5 5];


    % ---------------------------------------------------------------
    % Top-left: Original median + fitted function
    % ---------------------------------------------------------------
    
    axMedian = uiaxes(plotLayout);
    
    axMedian.Layout.Row = 1;
    axMedian.Layout.Column = 1;
    
    enableDefaultInteractivity(axMedian);
    
    
    % ---------------------------------------------------------------
    % Top-right: Residual
    % ---------------------------------------------------------------
    
    axResidual = uiaxes(plotLayout);
    
    axResidual.Layout.Row = 1;
    axResidual.Layout.Column = 2;
    
    enableDefaultInteractivity(axResidual);
    
    
    % ---------------------------------------------------------------
    % Bottom-left: Spectrogram of fitted function/ original median
    % ---------------------------------------------------------------
    
    axSpectrogramFit = uiaxes(plotLayout);
    
    axSpectrogramFit.Layout.Row = 2;
    axSpectrogramFit.Layout.Column = 1;
    
    colorbar(axSpectrogramFit);
    
    enableDefaultInteractivity(axSpectrogramFit);
    
    
    % ---------------------------------------------------------------
    % Bottom-right: Spectrogram of residual
    % ---------------------------------------------------------------
    
    axSpectrogramResidual = uiaxes(plotLayout);
    
    axSpectrogramResidual.Layout.Row = 2;
    axSpectrogramResidual.Layout.Column = 2;
    
    colorbar(axSpectrogramResidual);
    
    enableDefaultInteractivity(axSpectrogramResidual);
    
    
    colormap(axSpectrogramFit, turbo);
    colormap(axSpectrogramResidual, turbo);
    
    
    % Link the time axes
    linkaxes([ ...
        axMedian, ...
        axResidual, ...
        axSpectrogramFit, ...
        axSpectrogramResidual], 'x');


    % ---------------------------------------------------------------
    % Callbacks
    % ---------------------------------------------------------------

    fitFunctionDropDown.ValueChangedFcn = ...
        @(~,~) updateFit();

    polynomialOrderField.ValueChangedFcn = ...
        @(source,~) updatePolynomialOrder(source);

    smoothingField.ValueChangedFcn = ...
        @(source,~) updateSmoothing(source);

    numberExponentialsField.ValueChangedFcn = ...
    @(source,~) updateNumberExponentials(source);

    maximumFrequencyField.ValueChangedFcn = ...
        @(source,~) updateFrequencyLimit(source);

    maximumCbar1Field.ValueChangedFcn = ...
        @(source,~) updateCbar1Limit(source);

    maximumCbar2Field.ValueChangedFcn = ...
        @(source,~) updateCbar2Limit(source);


    % Initial fit

    updateFit();


    % ===============================================================
    % Nested functions
    % ===============================================================


    function updatePolynomialOrder(source)

        polynomialOrder = round(source.Value);

        polynomialOrder = max(0, min(polynomialOrder, 5000));

        source.Value = polynomialOrder;

        if strcmp(fitFunctionDropDown.Value, 'Polynomial')
            updateFit();
        end

    end


    function updateSmoothing(source)

        smoothingParameter = source.Value;

        smoothingParameter = ...
            max(0, min(smoothingParameter, 1));

        source.Value = smoothingParameter;

        if strcmp(fitFunctionDropDown.Value, 'Smoothing spline')
            updateFit();
        end

    end

    function updateNumberExponentials(source)

        numberExponentials = round(source.Value);
    
        numberExponentials = ...
            max(1, min(numberExponentials, 500));
    
        source.Value = numberExponentials;
    
        if strcmp(fitFunctionDropDown.Value, ...
                'Multi-exponentials')
    
            updateFit();
    
        end
    
    end

    function updateFrequencyLimit(source)

        maximumFrequency = min(max( ...
            source.Value, 1), samplingRateHz/2);

        source.Value = maximumFrequency;

        ylim(axSpectrogramFit, [0 maximumFrequency]);
        ylim(axSpectrogramResidual, [0 maximumFrequency]);


    end

    function updateCbar1Limit(source)

        if isempty(source.Value)           
            updateFit();
            return;
        end

        maxCbar1Value = min(maximumSpecgramColorbarValue, source.Value);
        source.Value = maxCbar1Value;

        cbar1Limits = [maxCbar1Value - spectrogramDynamicRangeDb, maxCbar1Value];

        clim(axSpectrogramFit, cbar1Limits);
    end


    function updateCbar2Limit(source)

        if isempty(source.Value)           
            updateFit();
            return;
        end

        maxCbar2Value = min(maximumSpecgramColorbarValue, source.Value);
        source.Value = maxCbar2Value;

        cbar2Limits = [maxCbar2Value - spectrogramDynamicRangeDb, maxCbar2Value];

        clim(axSpectrogramResidual, cbar2Limits);
    end
        

    function displayName = methodToDisplayName(method)
    
        switch lower(string(method))
    
            case {"poly", "polynomial"}
                displayName = 'Polynomial';
    
            case {"spline", "smoothingspline", "smoothing spline"}
                displayName = 'Smoothing spline';
    
            case {"cubic", "cubicspline", "cubic spline"}
                displayName = 'Cubic spline';
    
            case {"pchip"}
                displayName = 'PCHIP';

            case{"expo", "multi expo"}
                displayName = 'Multi-exponentials';
    
            otherwise
                displayName = 'Polynomial';
    
        end
    
    end


    % ---------------------------------------------------------------
    % Main fitting function
    % ---------------------------------------------------------------

    function updateFit()

        method = fitFunctionDropDown.Value;

        statusLabel.Text = sprintf( ...
            'Fitting %s...', method);

        drawnow;


        fitTimer = tic;


        try

            switch method

                case 'Polynomial'

                    order = polynomialOrderField.Value;

                    fittedMedian = fitPolynomialFunction( ...
                        time, ...
                        originalMedian, ...
                        order);


                    fitDescription = ...
                        sprintf('Polynomial order %d', order);


                case 'Smoothing spline'

                    smoothingParameter = smoothingField.Value;

                    fittedMedian = fitSmoothingSplineFunction( ...
                        time, ...
                        originalMedian, ...
                        smoothingParameter);


                    fitDescription = ...
                        sprintf('Smoothing spline, p = %.4g', ...
                        smoothingParameter);


                case 'Cubic spline'

                    fittedMedian = fitCubicSplineFunction( ...
                        time, ...
                        originalMedian);


                    fitDescription = ...
                        'Cubic spline interpolation';


                case 'PCHIP'

                    fittedMedian = fitPchipFunction( ...
                        time, ...
                        originalMedian);


                    fitDescription = ...
                        'PCHIP interpolation';

                case 'Multi-exponentials'

                    numberExponentials = ...
                        round(numberExponentialsField.Value);
                
                    [fittedMedian, ~] = fitMultipleExponentials( ...
                        time, ...
                        originalMedian, ...
                        numberExponentials);
                
                    fitDescription = sprintf( ...
                        '%d exponential%s', ...
                        numberExponentials, ...
                        pluralSuffix(numberExponentials));


                otherwise

                    error('Unknown fitting method: %s', method);

            end


        catch ME

            statusLabel.Text = 'Fit failed.';

            uialert(fig, ...
                ME.message, ...
                'Fitting error');

            return;

        end


        elapsedSeconds = toc(fitTimer);

        % residual ------------------------

        % residual = originalMedian - fittedMedian;
        % -----------------------------------------------------------
        % Enforce exact endpoint matching
        % -----------------------------------------------------------
        
        fittedMedian = forceEndpointMatch( ...
            time, ...
            originalMedian, ...
            fittedMedian);
        
        % Residual
        residual = originalMedian - fittedMedian;

        % -----------------------------------------------------------
        % Fit quality
        % -----------------------------------------------------------

        valid = ...
            isfinite(originalMedian) & ...
            isfinite(fittedMedian);

        if nnz(valid) >= 2

            residual = ...
                originalMedian(valid) - fittedMedian(valid);

            fitRMSE = sqrt(mean(residual.^2));

            correlationMatrix = corrcoef( ...
                originalMedian(valid), ...
                fittedMedian(valid));

            if all(size(correlationMatrix) == [2 2])
                fitCorrelation = correlationMatrix(1,2);
            else
                fitCorrelation = NaN;
            end

        else

            fitRMSE = NaN;
            fitCorrelation = NaN;

        end


        % -----------------------------------------------------------
        % Top-left Plotting: Original median + fitted function
        % -----------------------------------------------------------
        
        cla(axMedian);
        
        plot(axMedian, ...
            time, ...
            originalMedian, ...
            'Color', [0.65 0.65 0.65], ...
            'LineWidth', 1.1, ...
            'DisplayName', 'Original median');
        
        hold(axMedian, 'on');
        
        plot(axMedian, ...
            time, ...
            fittedMedian, ...
            'k', ...
            'LineWidth', 2, ...
            'DisplayName', fitDescription);
        
        hold(axMedian, 'off');
        
        grid(axMedian, 'on');
        
        xlabel(axMedian, 'Time (s)');
        ylabel(axMedian, 'Amplitude');
        
        title(axMedian, fitDescription);
        
        legend(axMedian, 'Location', 'best');


        % -----------------------------------------------------------
        % Top-right Plotting: Residual
        % -----------------------------------------------------------
        
        cla(axResidual);
        
        plot(axResidual, ...
            time, ...
            residual, ...
            'Color', [0.5, 0, 0.5], ...     % [0.5, 0, 0.5] - purple, [0.6941, 0.6118, 0.8510] - light purple
            'LineWidth', 1.4);
        
        hold(axResidual, 'on');
        
        yline(axResidual, 0, '--');
        
        hold(axResidual, 'off');
        
        grid(axResidual, 'on');
        
        xlabel(axResidual, 'Time (s)');
        ylabel(axResidual, 'Amplitude');
        
        title(axResidual, ...
            'Residual: Original median - fitted');


        % -----------------------------------------------------------
        % calculating Spectrogram of original/fitted median
        % -----------------------------------------------------------
        
        sig = originalMedian;       % fittedMedian, originalMedian
        validFit = isfinite(sig);
        
        if nnz(validFit) < 20
        
            cla(axSpectrogramFit);
            cla(axSpectrogramResidual);
        
            statusLabel.Text = ...
                'Too few valid samples for spectrogram.';
        
            return;
        
        end
        
        
        validTimeFit = time(validFit);
        validSignalFit = sig(validFit);
        
        
        [powerDbFit, frequencyFit, specTimeFit] = ...
            calculateSpectrogramDb( ...
                validSignalFit, ...
                validTimeFit, ...
                samplingRateHz, ...
                spectrogramWindowSeconds, ...
                spectrogramOverlapFraction);
        
        
        % -----------------------------------------------------------
        % calculating Spectrogram of residual
        % -----------------------------------------------------------
        
        validResidual = isfinite(residual);
        
        validTimeResidual = time(validResidual);
        validSignalResidual = residual(validResidual);
        
        
        [powerDbResidual, frequencyResidual, specTimeResidual] = ...
            calculateSpectrogramDb( ...
                validSignalResidual, ...
                validTimeResidual, ...
                samplingRateHz, ...
                spectrogramWindowSeconds, ...
                spectrogramOverlapFraction);

        % -----------------------------------------------------------
        % Plotting Bottom-left: fitted spectrogram
        % -----------------------------------------------------------
        
        maximumDbFit = max(powerDbFit(:));
        maximumDbResidual = max(powerDbResidual(:));

        maximumDb = max([ ...
            powerDbFit(:); ...
            powerDbResidual(:)]);
        
        colorLimits = [ ...
            maximumDb - spectrogramDynamicRangeDb, ...
            maximumDb];  
        colorLimitsFit = [ ...
            maximumDbFit - spectrogramDynamicRangeDb, ...
            maximumDbFit];
        colorLimitsResidual = [ ...
            maximumDbResidual - spectrogramDynamicRangeDb, ...
            maximumDbResidual];
        
        cla(axSpectrogramFit);
        
        imagesc( ...
            axSpectrogramFit, ...
            specTimeFit, ...
            frequencyFit, ...
            powerDbFit);
        
        axis(axSpectrogramFit, 'xy');
        
        ylim(axSpectrogramFit, ...
            [0 maximumFrequencyField.Value]);
        
        clim(axSpectrogramFit, colorLimitsFit);
        
        xlabel(axSpectrogramFit, 'Time (s)');
        ylabel(axSpectrogramFit, 'Frequency (Hz)');
        
        if sig==originalMedian
            title(axSpectrogramFit, ...
                'Spectrogram of original median artifact');
        elseif sig==fittedMedian
            title(axSpectrogramFit, ...
            'Spectrogram of fitted artifact');
        end
        
        colorbar(axSpectrogramFit);
        
        
        % -----------------------------------------------------------
        % Plotting Bottom-right: residual spectrogram
        % -----------------------------------------------------------
                
        cla(axSpectrogramResidual);
        
        imagesc( ...
            axSpectrogramResidual, ...
            specTimeResidual, ...
            frequencyResidual, ...
            powerDbResidual);
        
        axis(axSpectrogramResidual, 'xy');
        
        ylim(axSpectrogramResidual, ...
            [0 maximumFrequencyField.Value]);
        
        clim(axSpectrogramResidual, colorLimitsResidual);
        
        xlabel(axSpectrogramResidual, 'Time (s)');
        ylabel(axSpectrogramResidual, 'Frequency (Hz)');
        
        title(axSpectrogramResidual, ...
            'Spectrogram of residual');
        
        colorbar(axSpectrogramResidual);


        % -----------------------------------------------------------
        % Status
        % -----------------------------------------------------------

        statusLabel.Text = sprintf( ...
            '%s | Fit time %.3f s', ...
            fitDescription, ...
            elapsedSeconds);

        fitInfoLabel.Text = sprintf( ...
            'RMSE %.4g | r %.5f', ...
            fitRMSE, ...
            fitCorrelation);


        % Store results

        fig.UserData = struct( ...
            'FitMethod', method, ...
            'PolynomialOrder', polynomialOrder, ...
            'SmoothingParameter', smoothingParameter, ...
            'OriginalMedian', originalMedian, ...
            'FittedMedian', fittedMedian, ...
            'FitRMSE', fitRMSE, ...
            'FitCorrelation', fitCorrelation, ...
            'FitTimeSeconds', elapsedSeconds);


        drawnow limitrate;

        function suffix = pluralSuffix(n)

            if n == 1
                suffix = '';
            else
                suffix = 's';
            end
        
        end

    end

fprintf('\n\n Launched Median Artifact Fit Explorer\n\n')

end


function fittedValues = fitPolynomialFunction_badlyConditioned( ...
    time, signal, polynomialOrder)

    time = time(:);
    signal = signal(:);

    valid = ...
        isfinite(time) & ...
        isfinite(signal);

    if nnz(valid) < polynomialOrder + 1

        error([ ...
            'Polynomial order %d requires at least %d valid samples. ' ...
            'Only %d valid samples are available.'], ...
            polynomialOrder, ...
            polynomialOrder + 1, ...
            nnz(valid));

    end


    t = time(valid);
    y = signal(valid);


    % ---------------------------------------------------------------
    % IMPORTANT:
    %
    % Do NOT fit directly using:
    %
    %       polyfit(t,y,N)
    %
    % when N is large and t is in seconds.
    %
    % Instead scale time to [-1,1].
    % ---------------------------------------------------------------

    tMin = min(t);
    tMax = max(t);

    if tMax <= tMin

        error('Time vector must contain at least two distinct values.');

    end


    scaledTime = ...
        2*(t - tMin)/(tMax - tMin) - 1;


    % Polynomial least-squares fit
    coefficients = polyfit( ...
        scaledTime, ...
        y, ...
        polynomialOrder);


    % Evaluate on the original complete time vector
    scaledTimeAll = ...
        2*(time - tMin)/(tMax - tMin) - 1;


    fittedValues = polyval( ...
        coefficients, ...
        scaledTimeAll);

    fittedValues = fittedValues(:).';

end


function fittedValues = fitPolynomialFunction( ...
    time, signal, polynomialOrder)

    time = time(:);
    signal = signal(:);

    valid = ...
        isfinite(time) & ...
        isfinite(signal);

    if nnz(valid) < polynomialOrder + 1

        error([ ...
            'Polynomial order %d requires at least %d valid samples. ' ...
            'Only %d valid samples are available.'], ...
            polynomialOrder, ...
            polynomialOrder + 1, ...
            nnz(valid));

    end


    % ---------------------------------------------------------------
    % Valid data
    % ---------------------------------------------------------------

    t = time(valid);
    y = signal(valid);


    % Sort time
    [t, sortIndex] = sort(t);
    y = y(sortIndex);


    % ---------------------------------------------------------------
    % Map time to [-1,1]
    % ---------------------------------------------------------------

    tMin = min(t);
    tMax = max(t);

    if tMax <= tMin
        error('Time vector must contain at least two distinct values.');
    end

    x = 2*(t - tMin)/(tMax - tMin) - 1;


    % ---------------------------------------------------------------
    % Construct Chebyshev design matrix
    %
    % T_0(x) = 1
    % T_1(x) = x
    % T_n(x) = 2*x*T_{n-1}(x) - T_{n-2}(x)
    % ---------------------------------------------------------------

    N = numel(x);
    P = polynomialOrder;

    X = zeros(N, P+1);

    X(:,1) = 1;

    if P >= 1
        X(:,2) = x;
    end

    for k = 2:P

        X(:,k+1) = ...
            2*x.*X(:,k) - X(:,k-1);

    end


    % ---------------------------------------------------------------
    % Least-squares fit
    %
    % Backslash is preferable to explicitly computing
    % inv(X'*X).
    % ---------------------------------------------------------------

    coefficients = X \ y;


    % ---------------------------------------------------------------
    % Evaluate fitted polynomial on ALL time points
    % ---------------------------------------------------------------

    xAll = ...
        2*(time - tMin)/(tMax - tMin) - 1;


    fittedValues = evaluateChebyshevPolynomial( ...
        xAll, ...
        coefficients);


    fittedValues = fittedValues(:).';

end


function y = evaluateChebyshevPolynomial(x, coefficients)

    x = x(:);

    P = numel(coefficients) - 1;

    % Start with highest-order term
    b1 = zeros(size(x));
    b2 = zeros(size(x));

    % Clenshaw recurrence
    %
    % This is much more numerically stable than explicitly calculating
    % T_0(x), T_1(x), ..., T_P(x) and multiplying each by its coefficient.

    for k = P:-1:1

        b0 = ...
            2*x.*b1 - b2 + coefficients(k+1);

        b2 = b1;
        b1 = b0;

    end

    y = ...
        x.*b1 - b2 + coefficients(1);

end


function fittedValues = fitSmoothingSplineFunction( ...
    time, signal, smoothingParameter)

    time = time(:);
    signal = signal(:);

    valid = ...
        isfinite(time) & ...
        isfinite(signal);

    if nnz(valid) < 5
        error('At least five valid samples are required for spline fitting.');
    end


    t = time(valid);
    y = signal(valid);


    % Ensure strictly increasing x-values
    [t, sortIndex] = sort(t);
    y = y(sortIndex);


    % MATLAB smoothing spline.
    %
    % p = 1  -> interpolation-like behaviour
    % p = 0  -> maximum smoothing
    %
    % Requires Curve Fitting Toolbox.

    splineFit = fit( ...
        t, ...
        y, ...
        'smoothingspline', ...
        'SmoothingParam', smoothingParameter);


    fittedValues = splineFit(time);

    fittedValues = fittedValues(:).';

end


function fittedValues = fitCubicSplineFunction( ...
    time, signal)

    time = time(:);
    signal = signal(:);

    valid = ...
        isfinite(time) & ...
        isfinite(signal);

    if nnz(valid) < 4
        error('At least four valid samples are required for cubic spline.');
    end


    t = time(valid);
    y = signal(valid);


    [t, sortIndex] = sort(t);
    y = y(sortIndex);


    % Cubic spline interpolation
    splineParameters = spline(t, y);


    fittedValues = ppval( ...
        splineParameters, ...
        time);


    fittedValues = fittedValues(:).';

end


function fittedValues = fitPchipFunction( ...
    time, signal)

    time = time(:);
    signal = signal(:);

    valid = ...
        isfinite(time) & ...
        isfinite(signal);

    if nnz(valid) < 3
        error('At least three valid samples are required for PCHIP.');
    end


    t = time(valid);
    y = signal(valid);


    [t, sortIndex] = sort(t);
    y = y(sortIndex);


    fittedValues = pchip( ...
        t, ...
        y, ...
        time);


    fittedValues = fittedValues(:).';

end


function [fittedValues, fittedExpoParams] = fitMultipleExponentials( ...
    time, signal, numberExponentials)

    time = time(:);
    signal = signal(:);

    valid = ...
        isfinite(time) & ...
        isfinite(signal);

    if nnz(valid) < 20
        error('Not enough valid samples for exponential fitting.');
    end


    % ---------------------------------------------------------------
    % Valid data
    % ---------------------------------------------------------------

    t = time(valid);
    y = signal(valid);

    [t, sortIndex] = sort(t);
    y = y(sortIndex);


    % Remove duplicate time values
    [t, uniqueIndex] = unique(t);
    y = y(uniqueIndex);


    K = numberExponentials;


    % ---------------------------------------------------------------
    % Shift time so that fitting starts at t = 0
    % ---------------------------------------------------------------

    t0 = min(t);

    tFit = t - t0;


    % ---------------------------------------------------------------
    % Initial estimates
    % ---------------------------------------------------------------

    baseline = median(y(end));

    signalAmplitude = y(1) - baseline;


    % If amplitude is very small, use data range instead
    if abs(signalAmplitude) < eps(max(abs(y)))

        signalAmplitude = ...
            max(y) - min(y);

    end


    % Initial amplitudes
    A0 = signalAmplitude / K * ones(K,1);


    % Estimate a range of time constants
    totalDuration = max(tFit);

    if totalDuration <= 0
        error('Time vector must contain more than one distinct value.');
    end


    % Log-spaced initial time constants
    tauMin = max(totalDuration / 100, ...
                 1 / (100 * max(1, 1/(t(2)-t(1)))));

    tauMax = totalDuration * 2;

    tau0 = logspace( ...
        log10(tauMin), ...
        log10(tauMax), ...
        K).';


    % ---------------------------------------------------------------
    % Parameter vector
    %
    % p = [baseline
    %      A1 ... AK
    %      tau1 ... tauK]
    % ---------------------------------------------------------------

    p0 = [ ...
        baseline; ...
        A0; ...
        tau0];


    % ---------------------------------------------------------------
    % Bounds
    % ---------------------------------------------------------------

    amplitudeScale = ...
        max(abs(y - baseline));

    if amplitudeScale == 0
        amplitudeScale = 1;
    end


    lowerAmplitude = ...
        -100 * amplitudeScale;

    upperAmplitude = ...
        100 * amplitudeScale;


    lowerTau = ...
        max(tauMin / 10, eps);

    upperTau = ...
        max(tauMax * 10, lowerTau * 10);


    lowerBounds = [ ...
        min(y) - 10*amplitudeScale; ...
        lowerAmplitude * ones(K,1); ...
        lowerTau * ones(K,1)];


    upperBounds = [ ...
        max(y) + 10*amplitudeScale; ...
        upperAmplitude * ones(K,1); ...
        upperTau * ones(K,1)];


    % ---------------------------------------------------------------
    % Model
    % ---------------------------------------------------------------

    modelFunction = @(p,t) ...
        exponentialModel(p,t,K);


    % ---------------------------------------------------------------
    % Optimization options
    % ---------------------------------------------------------------

    options = optimoptions( ...
        'lsqcurvefit', ...
        'Display', 'off', ...
        'MaxIterations', 1000, ...
        'MaxFunctionEvaluations', 5000, ...
        'FunctionTolerance', 1e-10, ...
        'StepTolerance', 1e-10);


    % ---------------------------------------------------------------
    % Fit
    % ---------------------------------------------------------------

    fittedParameters = lsqcurvefit( ...
        modelFunction, ...
        p0, ...
        tFit, ...
        y, ...
        lowerBounds, ...
        upperBounds, ...
        options);


    % ---------------------------------------------------------------
    % Evaluate on complete original time vector
    % ---------------------------------------------------------------

    tAll = time - t0;

    fittedValues = exponentialModel( ...
        fittedParameters, ...
        tAll, ...
        K);    

    fittedValues = fittedValues(:).';
    [fittedExpoParams.amplitudes, fittedExpoParams.timeConstants] = sortExponentialParameters(fittedParameters, K);

end


function y = exponentialModel(p, t, K)

    baseline = p(1);

    amplitudes = p(2:K+1);

    timeConstants = p(K+2:2*K+1);


    y = baseline * ones(size(t));


    for k = 1:K

        y = y + ...
            amplitudes(k) .* ...
            exp(-t ./ timeConstants(k));

    end

end


function [amplitudes, timeConstants] = ...
    sortExponentialParameters(p, K)

    amplitudes = p(2:K+1);

    timeConstants = p(K+2:2*K+1);

    [timeConstants, order] = sort(timeConstants);

    amplitudes = amplitudes(order);

end


function fittedValues = forceEndpointMatch( ...
    time, signal, fittedValues)

    time = time(:).';
    signal = signal(:).';
    fittedValues = fittedValues(:).';

    % Endpoint errors
    startError = fittedValues(1) - signal(1);
    endError   = fittedValues(end) - signal(end);

    % Linear correction connecting the two endpoint errors
    correction = startError + ...
        (endError - startError) .* ...
        (time - time(1)) ./ (time(end) - time(1));

    % Apply correction
    fittedValues = fittedValues - correction;

    % Force exact equality against any tiny floating-point residual
    fittedValues(1)   = signal(1);
    fittedValues(end) = signal(end);
end