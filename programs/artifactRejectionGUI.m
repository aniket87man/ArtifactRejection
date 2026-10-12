function artifactRejectionGUI(data, times, fs)
% ARTIFACTREJECTIONGUI
%
% GUI for visualization and artifact rejection of trials x time data.
%
% INPUTS
%   data : [NTrials x NTime] matrix
%   fs   : sampling frequency in Hz
%
%% ------------------------------------------------------------
%  Check input
% -------------------------------------------------------------

if ~ismatrix(data)
    error('data must be a trials x time matrix.');
end

[nTrials, nSamples] = size(data);

if nTrials < 1 || nSamples < 2
    error('data must contain at least one trial and two time samples.');
end

%% ------------------------------------------------------------
% Initial settings
% -------------------------------------------------------------

templateTypes = { ...
    'Median-based', ...
    'Polynomial', ...
    'Exponential', ...
    'Piecewise-linear'};

selectedTemplateType = templateTypes{1};

artifacRejectionMethods = { ...
    'Template subtraction' ...
    'Jitter and scale'};

selectedMethod = artifacRejectionMethods{1};

selectedTrial = 1;

% Time vector
t = (0:nSamples-1) / fs;

% Median signal
medianSignal = median(data, 1, 'omitnan');

medianSpikeTimes = [-0.010334 -0.0094; 0.03964 0.04056; 0.0896 0.0905; 0.13957 0.1405; 0.1895 0.1904; ...
    0.2395 0.24036; 0.28947 0.2903; 0.3394 0.3424];

medianSpikeLocs = zeros(size(medianSpikeTimes));

for i = 1:size(medianSpikeLocs, 1)
    medianSpikeLocs(i, 1) = find(times < medianSpikeTimes(i, 1), 1, 'last');
    medianSpikeLocs(i, 2) = find(times > medianSpikeTimes(i, 2), 1, 'first');
end
% artifactEnd = 

% Initial template and fit
template = generateTemplate( ...
    times, medianSignal, selectedTemplateType, medianSpikeLocs, fs);

fittedMedianTemplate = template;
% fitTemplate( ...
%     medianSignal, template, selectedTemplateType, fs);

% Fit first trial
% initially median is the template
trialTemplate = template;
% generateTemplate( ...
%     medianSignal, selectedTemplateType, fs);

fittedTrialTemplate = fitTemplate( ...
    times, data(1,:), trialTemplate, selectedMethod, fs);

%% ------------------------------------------------------------
% Create GUI
% -------------------------------------------------------------

fig = uifigure( ...
    'Name', 'Artifact Rejection Explorer', ...
    'Position', [50 50 1750 950], ...
    'Color', [0.94 0.94 0.94]);

%% ------------------------------------------------------------
% Main 3-column layout
% -------------------------------------------------------------

mainGrid = uigridlayout(fig, [1 3]);

mainGrid.ColumnWidth = {'1.15x', '1.15x', '1x'};
mainGrid.RowHeight = {'1x'};

mainGrid.ColumnSpacing = 8;
mainGrid.Padding = [8 8 8 8];

%% ============================================================
% LEFT PANEL -- MEDIAN
% =============================================================

leftPanel = uipanel(mainGrid);
leftPanel.Title = 'Median across trials';
leftPanel.FontWeight = 'bold';

leftGrid = uigridlayout(leftPanel, [5 1]);

leftGrid.RowHeight = {35, '1x', '1x', '1x', '1x'};
leftGrid.RowSpacing = 5;
leftGrid.Padding = [5 5 5 5];

%% Template dropdown

leftTemplateDropdown = uidropdown(leftGrid, ...
    'Items', templateTypes, ...
    'Value', selectedTemplateType, ...
    'ValueChangedFcn', @templateChanged);

leftTemplateDropdown.Tooltip = 'Choose artifact template method';

%% Axes

axMedian = uiaxes(leftGrid);
title(axMedian, 'Median signal + median fitted template');
xlabel(axMedian, 'Time (s)');
ylabel(axMedian, 'Amplitude');
grid(axMedian, 'on');

axMedianPSD = uiaxes(leftGrid);
title(axMedianPSD, 'PSD: median vs template');
xlabel(axMedianPSD, 'Frequency (Hz)');
ylabel(axMedianPSD, 'Power/Frequency');
grid(axMedianPSD, 'on');

axMedianSpec = uiaxes(leftGrid);
title(axMedianSpec, 'Median spectrogram');
xlabel(axMedianSpec, 'Time (s)');
ylabel(axMedianSpec, 'Frequency (Hz)');

axTemplateSpec = uiaxes(leftGrid);
title(axTemplateSpec, 'Template spectrogram');
xlabel(axTemplateSpec, 'Time (s)');
ylabel(axTemplateSpec, 'Frequency (Hz)');

%% ============================================================
% MIDDLE PANEL -- SELECTED TRIAL
% =============================================================

middlePanel = uipanel(mainGrid);
middlePanel.Title = 'Selected trial';
middlePanel.FontWeight = 'bold';

middleGrid = uigridlayout(middlePanel, [5 1]);

middleGrid.RowHeight = {35, '1x', '1x', '1x', '1x'};
middleGrid.RowSpacing = 5;
middleGrid.Padding = [5 5 5 5];

%% Row 1: Trial number + artifact rejection method

controlGrid = uigridlayout(middleGrid, [1 2]);
controlGrid.Layout.Row = 1;
controlGrid.ColumnWidth = {'1x', '1.5x'};
controlGrid.ColumnSpacing = 5;
controlGrid.Padding = [0 0 0 0];

% Trial dropdown

trialDropdown = uidropdown(controlGrid, ...
    'Items', createTrialNames(nTrials), ...
    'Value', 'Trial 1', ...
    'ValueChangedFcn', @trialChanged);

trialDropdown.Tooltip = 'Choose trial';

% Artifact rejection method dropdown

methodDropdown = uidropdown(controlGrid, ...
    'Items', artifacRejectionMethods, ...
    'Value', selectedMethod, ...
    'ValueChangedFcn', @methodChanged);

methodDropdown.Tooltip = 'Choose artifact rejection method';

%% Axes

axTrial = uiaxes(middleGrid);
title(axTrial, 'Selected trial + fitted artifact');
xlabel(axTrial, 'Time (s)');
ylabel(axTrial, 'Amplitude');
grid(axTrial, 'on');

axTrialPSD = uiaxes(middleGrid);
title(axTrialPSD, 'PSD: trial vs fitted artifact');
xlabel(axTrialPSD, 'Frequency (Hz)');
ylabel(axTrialPSD, 'Power/Frequency');
grid(axTrialPSD, 'on');

axTrialSpec = uiaxes(middleGrid);
title(axTrialSpec, 'Selected trial spectrogram');
xlabel(axTrialSpec, 'Time (s)');
ylabel(axTrialSpec, 'Frequency (Hz)');

axTrialTemplateSpec = uiaxes(middleGrid);
title(axTrialTemplateSpec, 'Template spectrogram');
xlabel(axTrialTemplateSpec, 'Time (s)');
ylabel(axTrialTemplateSpec, 'Frequency (Hz)');

%% ============================================================
% RIGHT PANEL -- ALL TRIALS
% =============================================================

rightPanel = uipanel(mainGrid);
rightPanel.Title = 'All trials: artifact rejection';
rightPanel.FontWeight = 'bold';

rightGrid = uigridlayout(rightPanel, [3 1]);

rightGrid.RowHeight = {35, '1x', '1x'};
rightGrid.RowSpacing = 5;
rightGrid.Padding = [5 5 5 5];

%% Run artifact rejection button

runButton = uibutton(rightGrid, ...
    'Text', 'Run artifact rejection', ...
    'ButtonPushedFcn', @runArtifactRejection);

runButton.FontWeight = 'bold';

%% Before rejection

axBefore = uiaxes(rightGrid);

title(axBefore, ...
    'Average spectrogram - BEFORE artifact rejection');

xlabel(axBefore, 'Time (s)');
ylabel(axBefore, 'Frequency (Hz)');

%% After rejection

axAfter = uiaxes(rightGrid);

title(axAfter, ...
    'Average spectrogram - AFTER artifact rejection');

xlabel(axAfter, 'Time (s)');
ylabel(axAfter, 'Frequency (Hz)');

% % fitOptions = optimoptions( ...
% %     'lsqcurvefit', ...
% %     'Algorithm', 'trust-region-reflective', ...
% %     'Display', 'off', ...
% %     'FiniteDifferenceType', 'central', ...
% %     'TypicalX', [1; 0.001], ...
% %     'MaxFunctionEvaluations', 500, ...
% %     'FunctionTolerance', 1e-10, ...
% %     'StepTolerance', 1e-10, ...
% %     'OptimalityTolerance', 1e-10);
% % 
% % maximumShiftSeconds = 0.01;
% % 
% % initialParameters = [1; 0];         % [gain; shiftSeconds]
% % lowerBounds = [0; -maximumShiftSeconds];
% % upperBounds = [Inf; maximumShiftSeconds];
% % 
% % % Every possible shift must remain inside the recorded template.
% % commonFitMask = ...
% %     times >= times(1) + maximumShiftSeconds & ...
% %     times <= times(end) - maximumShiftSeconds & ...
% %     isfinite(medianArtifact);
% % 
% % fitIndices = find(commonFitMask);
% % 
% % fitStride = max(1, round(samplingRateHz / fitSearchRateHz));
% % fitIndices = fitIndices(1:fitStride:end);
% % 
% % if numel(fitIndices) < 20
% %     error('Too few valid samples are available for lsqcurvefit.');
% % end
% % 
% % fitTime = time(fitIndices);

%% ------------------------------------------------------------
% Initial plotting
% -------------------------------------------------------------

updateMedianPlots();
updateTrialPlots();

%% ============================================================
% CALLBACK: TEMPLATE DROPDOWN
% =============================================================

function templateChanged(src, ~)

    selectedTemplateType = src.Value;

    % Update median
    template = generateTemplate( ...
        times, medianSignal, selectedTemplateType, medianSpikeLocs, fs);
    % 
    fittedMedianTemplate = template;

    % Update selected trial
    currentTrial = data(selectedTrial,:);

    trialTemplate = template;

    fittedTrialTemplate = fitTemplate( ...
        times, currentTrial, trialTemplate, selectedMethod, fs);

    updateMedianPlots();
    updateTrialPlots();

end

%% ============================================================
% CALLBACK: TRIAL DROPDOWN
% =============================================================

function trialChanged(src, ~)

    % Extract trial number
    selectedTrial = sscanf(src.Value, 'Trial %d');

    currentTrial = data(selectedTrial,:);

    % Generate template
    trialTemplate = template;
    % Fit template
    fittedTrialTemplate = fitTemplate( ...
        times, ...
        currentTrial, ...
        trialTemplate, ...
        selectedMethod, ...
        fs);

    updateTrialPlots();

end

%% ============================================================
% UPDATE ARTIFACT REJECTION METHOD
% =============================================================

function methodChanged(src, ~)

    selectedMethod = src.Value;

    currentTrial = data(selectedTrial,:);

    % Generate template
    trialTemplate = template;

    fittedTrialTemplate = fitTemplate( ...
        times, currentTrial, trialTemplate, selectedMethod, fs);

    % Update the selected-trial display
    updateTrialPlots();

end

%% ============================================================
% UPDATE MEDIAN PLOTS
% =============================================================

function updateMedianPlots()

    % ---------------------------------------------------------
    % 1. Median signal + fitted template
    % ---------------------------------------------------------

    cla(axMedian);

    plot(axMedian, ...
        times, medianSignal, ...
        'LineWidth', 1.2);

    hold(axMedian, 'on');

    plot(axMedian, ...
        times, fittedMedianTemplate, ...
        'LineWidth', 1.5);

    hold(axMedian, 'off');

    legend(axMedian, ...
        {'Median', 'Median Fitted Template'}, ...
        'Location', 'best');

    title(axMedian, ...
        ['Median + median fitted template (' ...
        selectedTemplateType ')']);

    xlabel(axMedian, 'Time (s)');
    ylabel(axMedian, 'Amplitude');

    grid(axMedian, 'on');

    % ---------------------------------------------------------
    % 2. PSD
    % ---------------------------------------------------------

    PSDxlims = [0 150];

    cla(axMedianPSD);

    N = length(medianSignal);
    freqVals = (0:N-1) * (fs / N);

    Pmed = abs(fft(medianSignal));

    Ptemp = abs(fft(fittedMedianTemplate));

    plot(axMedianPSD, freqVals, 10*log10(Pmed), ...
        'LineWidth', 1.2);

    hold(axMedianPSD, 'on');

    plot(axMedianPSD, freqVals, 10*log10(Ptemp), ...
        'LineWidth', 1.2);

    hold(axMedianPSD, 'off');
    xlim(axMedianPSD, PSDxlims);

    legend(axMedianPSD, ...
        {'Median', 'Median Fitted Template'}, ...
        'Location', 'best');

    grid(axMedianPSD, 'on');

    % ---------------------------------------------------------
    % 3. Median spectrogram
    % ---------------------------------------------------------

    cla(axMedianSpec);

    plotSpectrogram( ...
        axMedianSpec, ...
        medianSignal, ...
        fs, ...
        'Median spectrogram');

    % ---------------------------------------------------------
    % 4. Template spectrogram
    % ---------------------------------------------------------

    cla(axTemplateSpec);

    plotSpectrogram( ...
        axTemplateSpec, ...
        fittedMedianTemplate, ...
        fs, ...
        'Median Fitted Template Spectrogram');

end

%% ============================================================
% UPDATE SELECTED TRIAL PLOTS
% =============================================================

function updateTrialPlots()

    currentTrial = data(selectedTrial,:);

    % ---------------------------------------------------------
    % 1. Trial + fitted template
    % ---------------------------------------------------------

    cla(axTrial);

    plot(axTrial, ...
        times, currentTrial, ...
        'LineWidth', 1.2);

    hold(axTrial, 'on');

    plot(axTrial, ...
        times, fittedTrialTemplate, ...
        'LineWidth', 1.4);

    cleanedTrial = removeArtifact(currentTrial, fittedTrialTemplate, medianSpikeLocs);

    plot(axTrial, ...
        times, cleanedTrial, 'k', ...
        'LineWidth', 1.5);

    hold(axTrial, 'off');

    legend(axTrial, ...
        {sprintf('Trial %d', selectedTrial), ...
         'Fitted Artifact', 'Artifact Cleaned Trial'}, ...
        'Location', 'best');

    title(axTrial, ...
        sprintf('Trial %d + fitted artifact (%s)', ...
        selectedTrial, selectedTemplateType));

    xlabel(axTrial, 'Time (s)');
    ylabel(axTrial, 'Amplitude');

    grid(axTrial, 'on');

    % ---------------------------------------------------------
    % 2. PSD
    % ---------------------------------------------------------

    PSDxlims = [0 150];

    N = length(medianSignal);
    freqVals = (0:N-1) * (fs / N);

    cla(axTrialPSD);

    Ptrial = abs(fft(currentTrial));

    Ptemp = abs(fft(fittedTrialTemplate));

    Pcleaned = abs(fft(cleanedTrial));

    plot(axTrialPSD, ...
        freqVals, 10*log10(Ptrial), ...
        'LineWidth', 1.2);

    hold(axTrialPSD, 'on');

    plot(axTrialPSD, ...
        freqVals, 10*log10(Ptemp), ...
        'LineWidth', 1.2);

    % plot(axTrialPSD, ...
    %     freqVals, 10*log10(abs(Ptrial - Ptemp) + eps), 'k', ...
    %     'LineWidth', 1.4);

    plot(axTrialPSD, ...
        freqVals, 10*log10(Pcleaned), 'k', ...
        'LineWidth', 1.4);

    hold(axTrialPSD, 'off');
    xlim(axTrialPSD, PSDxlims);

    legend(axTrialPSD, ...
        {'Trial', 'Fitted Artifact', 'Artifact Cleaned Trial'}, ...
        'Location', 'best');

    grid(axTrialPSD, 'on');

    % ---------------------------------------------------------
    % 3. Trial spectrogram
    % ---------------------------------------------------------

    cla(axTrialSpec);

    plotSpectrogram( ...
        axTrialSpec, ...
        currentTrial, ...
        fs, ...
        sprintf('Trial %d spectrogram', selectedTrial));

    % ---------------------------------------------------------
    % 4. Template spectrogram
    % ---------------------------------------------------------

    cla(axTrialTemplateSpec);

    plotSpectrogram( ...
        axTrialTemplateSpec, ...
        currentTrial-fittedTrialTemplate, ...
        fs, ...
        '(Trial - Fitted Artifact) spectrogram');

end

%% ============================================================
% RUN ARTIFACT REJECTION
% =============================================================

function runArtifactRejection(~, ~)

    % Disable button while processing
    runButton.Enable = 'off';

    drawnow;

    try

        cleanedData = zeros(size(data));

        % -----------------------------------------------------
        % Process every trial
        % -----------------------------------------------------

        for k = 1:nTrials

            currentTrial = data(k,:);

            medianTemplate = generateTemplate( times, ...
                medianSignal, ...
                selectedTemplateType, ...
                medianSpikeLocs, ...
                fs);

            % Generate template
            currentTemplate = medianTemplate;

            % Fit template
            fittedTemplate = fitTemplate( ...
                times, ...
                currentTrial, ...
                currentTemplate, ...
                selectedMethod, ...
                fs);

            % Remove artifact
            cleanedData(k,:) = removeArtifact( ...
                currentTrial, ...
                fittedTemplate, ...
                medianSpikeLocs);

            % Progress
            if mod(k, max(1, floor(nTrials/10))) == 0
                drawnow;
            end

        end

        % -----------------------------------------------------
        % Average BEFORE spectrogram
        % -----------------------------------------------------

        [avgBefore, fBefore, tBefore] = ...
            averageSpectrogram(data, fs);

        % -----------------------------------------------------
        % Average AFTER spectrogram
        % -----------------------------------------------------

        [avgAfter, fAfter, tAfter] = ...
            averageSpectrogram(cleanedData, fs);

        % -----------------------------------------------------
        % Plot BEFORE
        % -----------------------------------------------------

        cla(axBefore);

        imagesc(axBefore, ...
            tBefore, ...
            fBefore, ...
            10*log10(avgBefore + eps));

        axis(axBefore, 'xy');
        ylim(axBefore, [0 100]);
        colormap(axBefore, jet);
        colorbar(axBefore);

        title(axBefore, ...
            'Average spectrogram - BEFORE artifact rejection');

        xlabel(axBefore, 'Time (s)');
        ylabel(axBefore, 'Frequency (Hz)');

        % -----------------------------------------------------
        % Plot AFTER
        % -----------------------------------------------------

        cla(axAfter);

        imagesc(axAfter, ...
            tAfter, ...
            fAfter, ...
            10*log10(avgAfter + eps));

        axis(axAfter, 'xy');
        ylim(axAfter, [0 100]);
        colormap(axAfter, jet);
        colorbar(axAfter);

        title(axAfter, ...
            'Average spectrogram - AFTER artifact rejection');

        xlabel(axAfter, 'Time (s)');
        ylabel(axAfter, 'Frequency (Hz)');

        % -----------------------------------------------------
        % Store cleaned data
        % -----------------------------------------------------

        % Store in figure UserData so it can be retrieved later
        fig.UserData.cleanedData = cleanedData;

        % Optional: store the original data too
        fig.UserData.originalData = data;

        % Store selected template method
        fig.UserData.templateType = selectedTemplateType;

        uialert(fig, ...
            'Artifact rejection completed.', ...
            'Done', ...
            'Icon', 'success');

    catch ME

        uialert(fig, ...
            ME.message, ...
            'Artifact rejection failed', ...
            'Icon', 'error');

    end

    runButton.Enable = 'on';

end

%% ============================================================
% SPECTROGRAM PLOTTER
% =============================================================

function plotSpectrogram(ax, signal, fsLocal, plotTitle)

    signal = signal(:);

    % % Choose spectrogram parameters
    % windowLength = min(256, length(signal));
    % 
    % if windowLength < 8
    %     warning('Signal is too short for spectrogram.');
    %     return;
    % end
    % 
    % overlap = round(0.75 * windowLength);

    % Setup multitaper
    params.tapers   = [1 1];
    params.pad      = -1;
    params.Fs       = fs;
    params.fpass    = [0 250];

    movingWin = [0.25 0.025];

    % nfft = max(256, 2^nextpow2(windowLength));
    % 
    % [S, F, T] = spectrogram( ...
    %     signal, ...
    %     hamming(windowLength), ...
    %     overlap, ...
    %     nfft, ...
    %     fsLocal);
    % 
    % P = abs(S).^2;

    [P, T, F] = mtspecgramc(signal,movingWin,params);

    imagesc(ax, ...
        times(1) + T, ...
        F, ...
        10*log10(P.' + eps));

    axis(ax, 'xy');

    ylim(ax, [0 100])
    colormap(ax, jet);

    colorbar(ax);

    title(ax, plotTitle);

    xlabel(ax, 'Time (s)');
    ylabel(ax, 'Frequency (Hz)');

end

%% ============================================================
% AVERAGE SPECTROGRAM ACROSS TRIALS
% =============================================================

function [avgSpec, F, T] = averageSpectrogram(allData, fsLocal)

    [nTr, ~] = size(allData);

    movingWin = [0.25 0.025];

    params.tapers = [1 1];
    params.pad    = -1;
    params.Fs     = fsLocal;
    params.fpass  = [0 min(250, fsLocal/2)];

    avgSpec = [];

    for k = 1:nTr

        signal = allData(k,:).';

        [P, Tcurrent, Fcurrent] = ...
            mtspecgramc(signal, movingWin, params);

        % Convert to frequency x time for plotting
        P = P.';

        if k == 1
            avgSpec = zeros(size(P));
            T = Tcurrent;
            F = Fcurrent;
        else
            if ~isequal(size(P), size(avgSpec)) || ...
               ~isequal(Tcurrent, T) || ...
               ~isequal(Fcurrent, F)

                error('Spectrogram dimensions differ between trials.');
            end
        end

        % Accumulate linear power, NOT decibel values
        avgSpec = avgSpec + P;

    end

    % Average power first; convert to dB only when plotting
    avgSpec = avgSpec / nTr;

end

% function [avgSpec, F, T] = averageSpectrogram(allData, fsLocal)
% 
%     [nTr, ~] = size(allData);
% 
%     % First trial determines dimensions
%     firstSignal = allData(1,:);
% 
%     windowLength = min(256, length(firstSignal));
%     overlap = round(0.75 * windowLength);
%     nfft = max(256, 2^nextpow2(windowLength));
% 
%     [S, F, T] = spectrogram( ...
%         firstSignal, ...
%         hamming(windowLength), ...
%         overlap, ...
%         nfft, ...
%         fsLocal);
% 
%     avgSpec = abs(S).^2;
% 
%     % ---------------------------------------------------------
%     % Accumulate remaining trials
%     % ---------------------------------------------------------
% 
%     for k = 2:nTr
% 
%         signal = allData(k,:);
% 
%         [S, Ftmp, Ttmp] = spectrogram( ...
%             signal, ...
%             hamming(windowLength), ...
%             overlap, ...
%             nfft, ...
%             fsLocal);
% 
%         % Sanity check
%         if ~isequal(size(S), size(avgSpec))
%             error('Spectrogram dimensions differ between trials.');
%         end
% 
%         avgSpec = avgSpec + abs(S).^2;
% 
%     end
% 
%     avgSpec = avgSpec / nTr;
% 
% end

%% ============================================================
% TRIAL DROPDOWN NAMES
% =============================================================

function names = createTrialNames(N)

    names = cell(N,1);

    for ii = 1:N
        names{ii} = sprintf('Trial %d', ii);
    end

end

end


%% Helper functions

function template = generateTemplate(times, signal, templateType, spikeLocs, fs)

switch templateType

    case 'Median-based'

        template = signal;

    case 'Polynomial'
        answer = inputdlg('Enter a value for the number of polynomials to be used:', 'Input Window');

        if isempty(answer)
            disp('User cancelled the input.');
        end

        maxPolyOrder = 100;
        minPolyOrder = 3;

        polyOrder = str2double(answer{1});

        if polyOrder<minPolyOrder
            polyOrder = minPolyOrder;
        elseif polyOrder>maxPolyOrder
            polyOrder = maxPolyOrder;
        end

        template = signal;

        for i = 1:size(spikeLocs, 1)-1
            timeSeg = times(spikeLocs(i, 2):spikeLocs(i+1, 1));
            signalSeg = signal(spikeLocs(i, 2):spikeLocs(i+1, 1));
            fittedPoly = fitPolynomialFunction(timeSeg, signalSeg, polyOrder);

            template(spikeLocs(i, 2):spikeLocs(i+1, 1)) = fittedPoly;
        end

        timeSeg = times(spikeLocs(8, 2):end);
        signalSeg = signal(spikeLocs(8, 2):end);
        fittedPoly = fitPolynomialFunction(timeSeg, signalSeg, polyOrder);

        template(spikeLocs(8, 2):end) = fittedPoly;

    case 'Piecewise-linear'

        template = signal;

    case 'Exponential'

        template = signal;

        answer = inputdlg('Enter a value for the number of exponentials to be used:', 'Input Window');

        if isempty(answer)
            disp('User cancelled the input.');
        end

        maxExpoOrder = 100;
        minExpoOrder = 3;

        expoOrder = str2double(answer{1});

        if expoOrder<minExpoOrder
            expoOrder = minExpoOrder;
        elseif expoOrder>maxExpoOrder
            expoOrder = maxExpoOrder;
        end

        for i = 1:size(spikeLocs, 1)-1
            timeSeg = times(spikeLocs(i, 2):spikeLocs(i+1, 1));
            signalSeg = signal(spikeLocs(i, 2):spikeLocs(i+1, 1));
            fittedExpo = fitMultipleExponentials(timeSeg, signalSeg, expoOrder);

            template(spikeLocs(i, 2):spikeLocs(i+1, 1)) = fittedExpo;
        end

        timeSeg = times(spikeLocs(8, 2):end);
        signalSeg = signal(spikeLocs(8, 2):end);
        fittedExpo = fitMultipleExponentials(timeSeg, signalSeg, 5);

        template(spikeLocs(8, 2):end) = fittedExpo;

    otherwise
        error('Unknown template type.');

end

end


function fittedTemplate = fitTemplate( ...
    time, signal, template, methodType, fs)

if strcmp(methodType, 'Template subtraction')
fittedTemplate = template;

elseif strcmp(methodType, 'Jitter and scale')

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

    maximumShiftSeconds = 0.002;        % +/- 2 ms, 6 ms
    fitSearchRateHz = fs;             % Full LFP; reduced scoring for Raw

    initialParameters = [1; 0];         % [gain; shiftSeconds]
    lowerBounds = [0; -maximumShiftSeconds];
    upperBounds = [Inf; maximumShiftSeconds];

    % Every possible shift must remain inside the recorded template.
    commonFitMask = ...
        time >= time(1) + maximumShiftSeconds & ...
        time <= time(end) - maximumShiftSeconds;
    
    fitIndices = find(commonFitMask);
    
    fitStride = max(1, round(fs / fitSearchRateHz));
    fitIndices = fitIndices(1:fitStride:end);

    if numel(fitIndices) < 20
        error('Too few valid samples are available for lsqcurvefit.');
    end
    
    fitTime = time(fitIndices);

    fitResult = fitCurveJitterScale( ...
            signal, time, template, ...
            fitIndices, fitTime, ...
            initialParameters, lowerBounds, upperBounds, fitOptions);

    fittedTemplate = fitResult.FittedArtifact;
end

end


function cleanedSignal = removeArtifact( ...
    signal, fittedTemplate, spikeLocs)

cleanedSignal = signal - fittedTemplate;

numspikes = size(spikeLocs, 1);

for ii = 1:numspikes
    preVal = cleanedSignal(spikeLocs(ii, 1));
    postVal = cleanedSignal(spikeLocs(ii, 2));
    cleanedSignal(spikeLocs(ii, 1):spikeLocs(ii, 2)) = linspace(preVal, postVal, length(spikeLocs(ii, 1):spikeLocs(ii, 2)));
end

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


function fitResult = fitCurveJitterScale( ...
    signal, time, artifactTemplate, ...
    fitIndices, fitTime, ...
    initialParameters, lowerBounds, upperBounds, fitOptions)
% Fit one gain and one time shift with MATLAB lsqcurvefit.

    observedAtFitSamples = signal(fitIndices).';

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

    % fittedArtifact = shiftedTemplateModel( ...
    %     parameters, time(:), time, artifactTemplate).';
    shiftedTime = time - parameters(2);

    fittedArtifact = interp1( ...
        time(:), ...
        artifactTemplate, ...
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
