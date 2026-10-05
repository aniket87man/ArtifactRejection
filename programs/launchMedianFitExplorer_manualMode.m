function launchMedianFitExplorer_manualMode( ...
    time, medianArtifact, samplingRateHz, ...
    spectrogramWindowSeconds, spectrogramOverlapFraction, ...
    spectrogramDynamicRangeDb)

% Interactive explorer for manually fitting the median artifact.
%
% Top:
%   Median artifact + manually fitted/edited version
%
% Bottom:
%   Spectrogram of the current edited median artifact
%
% Three types of operations are supported:
%   1. Sigmoid fitting
%   2. Linear fitting
%   3. Linear interpolation
%
% Each range is specified on one line as:
%
%       startTime   endTime
%
% Example:
%
%       0.0417 0.0481
%       0.0917 0.0980
%       0.1416 0.1467


    % % ---------------------------------------------------------------
    %  Internal state
    % ---------------------------------------------------------------

    time = time(:).';
    originalMedian = medianArtifact(:).';

    editedMedian = originalMedian;

    maximumFrequency = samplingRateHz / 2;


    % % ---------------------------------------------------------------
    % Figure
    % ---------------------------------------------------------------

    fig = uifigure( ...
        'Name', 'Median Artifact Fit Explorer', ...
        'Position', [100, 60, 1500, 900]);


    outerLayout = uigridlayout(fig, [2,1]);

    outerLayout.RowHeight = {150, '1x'};
    outerLayout.Padding = [8 8 8 8];


    % % ---------------------------------------------------------------
    % Controls
    % ---------------------------------------------------------------

    controlLayout = uigridlayout(outerLayout, [4,6]);

    controlLayout.Layout.Row = 1;

    controlLayout.RowHeight = {30,40,40,40};

    controlLayout.ColumnWidth = ...
        {150, '1x', 120, 150, '1x', 100};

    controlLayout.Padding = [5 5 5 5];


    % ================================================================
    % Row 1
    % ================================================================

    uilabel(controlLayout, ...
        'Text', 'Spectrogram max Hz:', ...
        'HorizontalAlignment', 'right');

    maximumFrequencyField = uieditfield( ...
        controlLayout, 'numeric', ...
        'Value', maximumFrequency, ...
        'Limits', [1 maximumFrequency]);

    maximumFrequencyField.Layout.Row = 1;
    maximumFrequencyField.Layout.Column = 2;


    closeButton = uibutton(controlLayout, 'push', ...
        'Text', 'Close', ...
        'ButtonPushedFcn', @(~,~) close(fig));

    closeButton.Layout.Row = 1;
    closeButton.Layout.Column = 6;


    statusLabel = uilabel(controlLayout, ...
        'Text', 'Ready', ...
        'HorizontalAlignment', 'left');

    statusLabel.Layout.Row = 1;
    statusLabel.Layout.Column = [3 5];


    % ================================================================
    % Row 2 - Sigmoid
    % ================================================================

    uilabel(controlLayout, ...
        'Text', 'Sigmoid ranges (s):', ...
        'HorizontalAlignment', 'right');

    sigmoidField = uitextarea(controlLayout, ...
        'Value', {''});

    sigmoidField.Layout.Row = 2;
    sigmoidField.Layout.Column = 2;

    applySigmoidButton = uibutton( ...
        controlLayout, 'push', ...
        'Text', 'Apply Sigmoid');

    applySigmoidButton.Layout.Row = 2;
    applySigmoidButton.Layout.Column = 3;

    sigmoidExampleLabel = uilabel(controlLayout, ...
        'Text', 'one range per line');

    sigmoidExampleLabel.Layout.Row = 2;
    sigmoidExampleLabel.Layout.Column = [4 5];


    % ================================================================
    % Row 3 - Linear
    % ================================================================

    uilabel(controlLayout, ...
        'Text', 'Linear ranges (s):', ...
        'HorizontalAlignment', 'right');

    linearField = uitextarea(controlLayout, ...
        'Value', {''});

    linearField.Layout.Row = 3;
    linearField.Layout.Column = 2;

    applyLinearButton = uibutton( ...
        controlLayout, 'push', ...
        'Text', 'Apply Linear');

    applyLinearButton.Layout.Row = 3;
    applyLinearButton.Layout.Column = 3;

    linearExampleLabel = uilabel(controlLayout, ...
        'Text', 'one range per line');

    linearExampleLabel.Layout.Row = 3;
    linearExampleLabel.Layout.Column = [4 5];


    % ================================================================
    % Row 4 - Interpolation
    % ================================================================

    uilabel(controlLayout, ...
        'Text', 'Interpolation ranges (s):', ...
        'HorizontalAlignment', 'right');

    interpolationField = uitextarea(controlLayout, ...
        'Value', {''});

    interpolationField.Layout.Row = 4;
    interpolationField.Layout.Column = 2;

    applyInterpolationButton = uibutton( ...
        controlLayout, 'push', ...
        'Text', 'Apply Interpolation');

    applyInterpolationButton.Layout.Row = 4;
    applyInterpolationButton.Layout.Column = 3;

    interpolationExampleLabel = uilabel(controlLayout, ...
        'Text', 'one range per line');

    interpolationExampleLabel.Layout.Row = 4;
    interpolationExampleLabel.Layout.Column = [4 5];


    % % ---------------------------------------------------------------
    % Plot layout
    % ---------------------------------------------------------------

    plotLayout = uigridlayout(outerLayout, [2,1]);

    plotLayout.Layout.Row = 2;

    plotLayout.RowHeight = {'1x','1x'};

    plotLayout.Padding = [5 5 5 5];


    % % Top plot

    axMedian = uiaxes(plotLayout);

    axMedian.Layout.Row = 1;

    enableDefaultInteractivity(axMedian);


    % % Bottom plot

    axSpectrogram = uiaxes(plotLayout);

    axSpectrogram.Layout.Row = 2;

    colorbar(axSpectrogram);
    colormap(axSpectrogram, turbo);

    enableDefaultInteractivity(axSpectrogram);


    linkaxes([axMedian axSpectrogram], 'x');


    % % ---------------------------------------------------------------
    % Callbacks
    % ---------------------------------------------------------------

    maximumFrequencyField.ValueChangedFcn = ...
        @(source,~) updateFrequencyLimit(source);

    applySigmoidButton.ButtonPushedFcn = ...
        @(~,~) applySigmoidFits();

    applyLinearButton.ButtonPushedFcn = ...
        @(~,~) applyLinearFits();

    applyInterpolationButton.ButtonPushedFcn = ...
        @(~,~) applyInterpolation();


    % % Initial plot

    updateFigure();


    % % ===============================================================
    % Nested functions
    % ===============================================================

    function updateFrequencyLimit(source)

        maximumFrequency = min(max( ...
            source.Value, 1), samplingRateHz/2);

        source.Value = maximumFrequency;

        ylim(axSpectrogram, [0 maximumFrequency]);

    end


    % % ---------------------------------------------------------------
    % Apply sigmoid fits
    % ---------------------------------------------------------------

    function applySigmoidFits()

        ranges = parseRanges(sigmoidField.Value);

        if isempty(ranges)
            uialert(fig, ...
                'Enter at least one valid sigmoid range.', ...
                'No sigmoid ranges');
            return;
        end

        statusLabel.Text = 'Fitting sigmoid segments...';
        drawnow;


        for k = 1:size(ranges,1)

            t1 = ranges(k,1);
            t2 = ranges(k,2);

            idx = find( ...
                time >= t1 & ...
                time <= t2 & ...
                isfinite(editedMedian));

            if numel(idx) < 10

                warning( ...
                    'Skipping sigmoid range %.6f - %.6f: too few samples.', ...
                    t1, t2);

                continue;
            end


            tFit = time(idx);
            yFit = editedMedian(idx);


            % % Initial sigmoid parameters

            yMin = min(yFit);
            yMax = max(yFit);

            amplitude = yMax - yMin;

            if abs(amplitude) < eps
                continue;
            end


            % Determine whether signal is rising or falling.
            if yFit(end) >= yFit(1)
                direction = 1;
            else
                direction = -1;
            end

            amplitude = direction * abs(amplitude);

            offset = mean([yFit(1), yFit(end)]);


            % Midpoint approximately halfway through the range.
            midpoint = mean([t1 t2]);


            % Initial slope.
            slope = 8 / max(t2-t1, eps);


            initialParameters = ...
                [offset, amplitude, slope, midpoint];


            % % Sigmoid model

            sigmoidModel = @(p,t) ...
                p(1) + ...
                p(2) ./ ...
                (1 + exp(-p(3) .* (t-p(4))));


            % % Bounds

            parameterLowerBounds = ...
                [-Inf, -Inf, -Inf, t1];

            parameterUpperBounds = ...
                [ Inf,  Inf,  Inf, t2];


            % % Fit

            fitOptions = optimoptions( ...
                'lsqcurvefit', ...
                'Display', 'off', ...
                'MaxFunctionEvaluations', 2000, ...
                'FunctionTolerance', 1e-10, ...
                'StepTolerance', 1e-10);


            try

                fittedParameters = lsqcurvefit( ...
                    sigmoidModel, ...
                    initialParameters, ...
                    tFit, ...
                    yFit, ...
                    parameterLowerBounds, ...
                    parameterUpperBounds, ...
                    fitOptions);


                fittedValues = ...
                    sigmoidModel(fittedParameters, tFit);


                editedMedian(idx) = fittedValues;


            catch ME

                uialert(fig, ...
                    sprintf( ...
                    'Sigmoid fit failed for %.6f - %.6f:\n\n%s', ...
                    t1, t2, ME.message), ...
                    'Sigmoid fit error');

                return;

            end

        end


        statusLabel.Text = ...
            sprintf('Applied %d sigmoid fit(s).', size(ranges,1));

        updateFigure();

    end


    % % ---------------------------------------------------------------
    % Apply linear fits
    % ---------------------------------------------------------------

    function applyLinearFits()

        ranges = parseRanges(linearField.Value);

        if isempty(ranges)

            uialert(fig, ...
                'Enter at least one valid linear range.', ...
                'No linear ranges');

            return;

        end


        statusLabel.Text = 'Fitting linear segments...';
        drawnow;


        for k = 1:size(ranges,1)

            t1 = ranges(k,1);
            t2 = ranges(k,2);

            idx = find( ...
                time >= t1 & ...
                time <= t2 & ...
                isfinite(editedMedian));


            if numel(idx) < 2

                warning( ...
                    'Skipping linear range %.6f - %.6f: too few samples.', ...
                    t1, t2);

                continue;

            end


            tFit = time(idx);
            yFit = editedMedian(idx);


            % % Linear least-squares fit

            coefficients = polyfit(tFit, yFit, 1);

            fittedValues = polyval( ...
                coefficients, tFit);


            editedMedian(idx) = fittedValues;

        end


        statusLabel.Text = ...
            sprintf('Applied %d linear fit(s).', size(ranges,1));

        updateFigure();

    end


    % % ---------------------------------------------------------------
    % Apply linear interpolation
    % ---------------------------------------------------------------

    function applyInterpolation()

        ranges = parseRanges(interpolationField.Value);

        if isempty(ranges)

            uialert(fig, ...
                'Enter at least one valid interpolation range.', ...
                'No interpolation ranges');

            return;

        end


        statusLabel.Text = 'Applying interpolation...';
        drawnow;


        for k = 1:size(ranges,1)

            t1 = ranges(k,1);
            t2 = ranges(k,2);

            idx = find( ...
                time >= t1 & ...
                time <= t2);


            if numel(idx) < 2
                continue;
            end


            left = idx(1) - 1;
            right = idx(end) + 1;


            if left < 1 || right > numel(editedMedian)

                warning( ...
                    'Skipping interpolation range %.6f - %.6f: ' ...
                    + "range touches signal boundary.", ...
                    t1, t2);

                continue;

            end


            editedMedian(idx) = interp1( ...
                [time(left), time(right)], ...
                [editedMedian(left), editedMedian(right)], ...
                time(idx), ...
                'linear');

        end


        statusLabel.Text = ...
            sprintf('Applied %d interpolation range(s).', ...
            size(ranges,1));

        updateFigure();

    end


    % % ---------------------------------------------------------------
    % Parse text-area ranges
    % ---------------------------------------------------------------

    function ranges = parseRanges(lines)

        ranges = [];

        if isempty(lines)
            return;
        end


        for k = 1:numel(lines)

            currentLine = strtrim(lines{k});

            if isempty(currentLine)
                continue;
            end


            values = sscanf(currentLine, '%f');


            if numel(values) ~= 2

                warning( ...
                    'Ignoring invalid range: "%s"', ...
                    currentLine);

                continue;

            end


            t1 = min(values);
            t2 = max(values);


            if t1 == t2
                continue;
            end


            % Restrict range to available time.
            t1 = max(t1, time(1));
            t2 = min(t2, time(end));


            if t2 <= t1
                continue;
            end


            ranges(end+1,:) = [t1 t2]; %#ok<AGROW>

        end

    end


    % % ---------------------------------------------------------------
    % Redraw figure
    % ---------------------------------------------------------------

    function updateFigure()

        % % Top: median

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
            editedMedian, ...
            'k', ...
            'LineWidth', 2, ...
            'DisplayName', 'Edited median');


        hold(axMedian, 'off');

        grid(axMedian, 'on');

        xlabel(axMedian, 'Time (s)');
        ylabel(axMedian, 'Amplitude');

        title(axMedian, ...
            'Median artifact: original vs fitted');

        legend(axMedian, 'Location', 'best');


        % % Bottom: spectrogram

        valid = isfinite(editedMedian);

        if nnz(valid) < 20
            return;
        end


        validTime = time(valid);
        validSignal = editedMedian(valid);


        [powerDb, frequency, specTime] = ...
            calculateSpectrogramDb( ...
                validSignal, ...
                validTime, ...
                samplingRateHz, ...
                spectrogramWindowSeconds, ...
                spectrogramOverlapFraction);


        maximumDb = max(powerDb(:));

        colorLimits = [ ...
            maximumDb - spectrogramDynamicRangeDb, ...
            maximumDb];


        cla(axSpectrogram);


        imagesc( ...
            axSpectrogram, ...
            specTime, ...
            frequency, ...
            powerDb);


        formatSpectrogramAxis( ...
            axSpectrogram, ...
            maximumFrequencyField.Value, ...
            colorLimits, ...
            'Spectrogram of edited median');


        % % Make sure frequency limit is respected

        ylim(axSpectrogram, ...
            [0 maximumFrequencyField.Value]);


        drawnow limitrate;

    end

end


%% Local functions

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