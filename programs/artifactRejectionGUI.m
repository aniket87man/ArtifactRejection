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
    'Piecewise-linear', ...
    'Exponential'};

selectedTemplateType = templateTypes{1};
selectedTrial = 1;

% Time vector
t = (0:nSamples-1) / fs;

% Median signal
medianSignal = median(data, 1, 'omitnan');

% Initial template and fit
template = generateTemplate( ...
    medianSignal, selectedTemplateType, fs);

fittedMedianTemplate = fitTemplate( ...
    medianSignal, template, selectedTemplateType, fs);

% Fit first trial
% initially median is the template
trialTemplate = generateTemplate( ...
    medianSignal, selectedTemplateType, fs);

fittedTrialTemplate = fitTemplate( ...
    data(1,:), trialTemplate, selectedTemplateType, fs);

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
title(axMedian, 'Median signal + fitted template');
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

%% Trial dropdown

trialDropdown = uidropdown(middleGrid, ...
    'Items', createTrialNames(nTrials), ...
    'Value', 'Trial 1', ...
    'ValueChangedFcn', @trialChanged);

trialDropdown.Tooltip = 'Choose trial';

%% Axes

axTrial = uiaxes(middleGrid);
title(axTrial, 'Selected trial + fitted template');
xlabel(axTrial, 'Time (s)');
ylabel(axTrial, 'Amplitude');
grid(axTrial, 'on');

axTrialPSD = uiaxes(middleGrid);
title(axTrialPSD, 'PSD: trial vs template');
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
        medianSignal, selectedTemplateType, fs);

    fittedMedianTemplate = fitTemplate( ...
        medianSignal, template, selectedTemplateType, fs);

    % Update selected trial
    currentTrial = data(selectedTrial,:);

    trialTemplate = generateTemplate( ...
        currentTrial, selectedTemplateType, fs);

    fittedTrialTemplate = fitTemplate( ...
        currentTrial, trialTemplate, selectedTemplateType, fs);

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
    trialTemplate = generateTemplate( ...
        currentTrial, selectedTemplateType, fs);

    % Fit template
    fittedTrialTemplate = fitTemplate( ...
        currentTrial, ...
        trialTemplate, ...
        selectedTemplateType, ...
        fs);

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
        {'Median', 'Fitted template'}, ...
        'Location', 'best');

    title(axMedian, ...
        ['Median + fitted template (' ...
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
        {'Median', 'Template'}, ...
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
        'Template spectrogram');

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
        t, currentTrial, ...
        'LineWidth', 1.2);

    hold(axTrial, 'on');

    plot(axTrial, ...
        t, fittedTrialTemplate, ...
        'LineWidth', 1.5);

    hold(axTrial, 'off');

    legend(axTrial, ...
        {sprintf('Trial %d', selectedTrial), ...
         'Fitted template'}, ...
        'Location', 'best');

    title(axTrial, ...
        sprintf('Trial %d + fitted template (%s)', ...
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

    plot(axTrialPSD, ...
        freqVals, 10*log10(Ptrial), ...
        'LineWidth', 1.2);

    hold(axTrialPSD, 'on');

    plot(axTrialPSD, ...
        freqVals, 10*log10(Ptemp), ...
        'LineWidth', 1.2);

    hold(axTrialPSD, 'off');
    xlim(axTrialPSD, PSDxlims);

    legend(axTrialPSD, ...
        {'Trial', 'Template'}, ...
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
        fittedTrialTemplate, ...
        fs, ...
        'Template spectrogram');

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

            % Generate template
            currentTemplate = generateTemplate( ...
                currentTrial, ...
                selectedTemplateType, ...
                fs);

            % Fit template
            fittedTemplate = fitTemplate( ...
                currentTrial, ...
                currentTemplate, ...
                selectedTemplateType, ...
                fs);

            % Remove artifact
            cleanedData(k,:) = removeArtifact( ...
                currentTrial, ...
                fittedTemplate, ...
                selectedTemplateType, ...
                fs);

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
        ylim(axBefore, [0 150]);
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
        ylim(axAfter, [0 150]);
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

    % Choose spectrogram parameters
    windowLength = min(256, length(signal));

    if windowLength < 8
        warning('Signal is too short for spectrogram.');
        return;
    end

    overlap = round(0.75 * windowLength);

    nfft = max(256, 2^nextpow2(windowLength));

    [S, F, T] = spectrogram( ...
        signal, ...
        hamming(windowLength), ...
        overlap, ...
        nfft, ...
        fsLocal);

    P = abs(S).^2;

    imagesc(ax, ...
        T, ...
        F, ...
        10*log10(P + eps));

    axis(ax, 'xy');

    ylim(ax, [0 150])
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

    % First trial determines dimensions
    firstSignal = allData(1,:);

    windowLength = min(256, length(firstSignal));
    overlap = round(0.75 * windowLength);
    nfft = max(256, 2^nextpow2(windowLength));

    [S, F, T] = spectrogram( ...
        firstSignal, ...
        hamming(windowLength), ...
        overlap, ...
        nfft, ...
        fsLocal);

    avgSpec = abs(S).^2;

    % ---------------------------------------------------------
    % Accumulate remaining trials
    % ---------------------------------------------------------

    for k = 2:nTr

        signal = allData(k,:);

        [S, Ftmp, Ttmp] = spectrogram( ...
            signal, ...
            hamming(windowLength), ...
            overlap, ...
            nfft, ...
            fsLocal);

        % Sanity check
        if ~isequal(size(S), size(avgSpec))
            error('Spectrogram dimensions differ between trials.');
        end

        avgSpec = avgSpec + abs(S).^2;

    end

    avgSpec = avgSpec / nTr;

end

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

function template = generateTemplate(signal, templateType, fs)

switch templateType

    case 'Median-based'

        template = signal;

    case 'Polynomial'

        template = signal;

    case 'Piecewise-linear'

        template = signal;

    case 'Exponential'

        template = signal;

    otherwise
        error('Unknown template type.');

end

end


function fittedTemplate = fitTemplate( ...
    signal, template, templateType, fs)

if strcmp(templateType, 'Median-based')
fittedTemplate = template;
end

end


function cleanedSignal = removeArtifact( ...
    signal, fittedTemplate, templateType, fs);

cleanedSignal = signal - fittedTemplate;

end
