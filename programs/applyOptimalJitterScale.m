% 
function [processedSignal, jitteredScaledErps] = applyOptimalJitterScale(signal, erp, timePosns)

N_signal = size(signal, 1);
N_x_indices = size(signal, 2);

if isempty(timePosns)
    [optimal_shifts, ~] = getCorrelations(signal, erp);                 %% 'using optimal jitter'

else
    [optimal_shifts, ~] = getCorrelations(signal(:, timePosns), erp(timePosns));                 %% 'using optimal jitter' only based on the artifact spike positions
end

assignin('base', 'Shifts_elec22', optimal_shifts);
shiftedErps = zeros(N_signal, N_x_indices);
bestAlphas = zeros(N_signal, 1);
jitteredScaledErps = zeros(N_signal, N_x_indices);

for i = 1:size(optimal_shifts, 1)
    tau = optimal_shifts(i);
    if tau>0
        shiftedErps(i, :) = [zeros(1, tau), erp(1:end-tau)];
    elseif tau<0
        shiftedErps(i, :) = [erp(1-tau:end), zeros(1, -tau)];
    else 
        shiftedErps(i, :) = erp;
    end
    % shifted_sigs(i, :) = interp1(x_indices, erp, x_indices-optimal_shifts(i), 'cubic', 0);
end

% shiftedSigs = repmat(erp, N_signal, 1);                               %% trying out 'not using optimal jitter'

for i = 1:N_signal
    si = signal(i, :);
    bestAlphas(i) = si*shiftedErps(i, :)'/norm(shiftedErps(i, :))^2;
    jitteredScaledErps(i, :) = bestAlphas(i)*shiftedErps(i, :);
end

processedSignal = signal - jitteredScaledErps;