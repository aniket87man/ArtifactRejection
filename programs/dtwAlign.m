function [distance, xAligned, yAligned, pathXY, info] = ...
    dtwAlign(x, y, varargin)
% DTWALIGN DTW distance, aligned signals, and warping path.
%
% Options:
%   'Norm'       : 'l1', 'l2', 'lp'
%   'P'          : exponent for 'lp' (default 2)
%   'Constraint' : 'none', 'sakoechiba', 'itakura'
%   'Radius'     : Sakoe-Chiba radius
%   'Slope'      : Itakura slope factor (default 2)
%   'Normalize'  : normalize cost by path length (default false)

prsr = inputParser;
addParameter(prsr,'Norm','l1');
addParameter(prsr,'P',2);
addParameter(prsr,'Constraint','none');
addParameter(prsr,'Radius',[]);
addParameter(prsr,'Slope',2);
addParameter(prsr,'Normalize',false);
parse(prsr,varargin{:});
o = prsr.Results;

x = x(:);
y = y(:);

if isempty(x) || isempty(y) || ...
        ~isreal(x) || ~isreal(y) || ...
        any(~isfinite(x)) || any(~isfinite(y))
    error('Inputs must be nonempty, finite real-valued vectors.');
end

n = numel(x);
m = numel(y);

normName = lower(char(o.Norm));
constraint = lower(char(o.Constraint));

if isempty(o.Radius)
    radius = max(n,m);
else
    radius = floor(o.Radius);
end

if ~ismember(normName,{'l1','l2','lp'})     %,'l2notSquared'})
    error('Invalid Norm.');
end

if ~ismember(constraint,{'none','sakoechiba','itakura'})
    error('Invalid Constraint.');
end

switch normName
    case 'l1'
        p = 1;
    case 'l2'
        p = 2;
    case 'lp'
        if o.P < 1
            error('P must be >= 1.');
        end
        p = o.P;
end

% Construct feasible alignment region.
validMask = false(n,m);

switch constraint
    case 'none'
        validMask(:) = true;

    case 'sakoechiba'
        for i = 1:n
            if n == 1
                center = 1 + (m-1)/2;
            else
                center = 1 + (i-1)*(m-1)/(n-1);
            end

            lo = max(1,ceil(center-radius));
            hi = min(m,floor(center+radius));

            if lo <= hi
                validMask(i,lo:hi) = true;
            end
        end

        validMask(1,1) = true;
        validMask(n,m) = true;

    case 'itakura'
        s = o.Slope;

        if s < 1
            error('Slope must be >= 1.');
        end

        for i = 1:n
            u = 0.5;
            if n > 1
                u = (i-1)/(n-1);
            end

            for j = 1:m
                v = 0.5;
                if m > 1
                    v = (j-1)/(m-1);
                end

                lo1 = u/s;
                hi1 = min(s*u,1);
                lo2 = 1-s*(1-u);
                hi2 = 1-(1-u)/s;

                validMask(i,j) = ...
                    v >= lo1 && v <= hi1 && ...
                    v >= lo2 && v <= hi2;
            end
        end

        validMask(1,1) = true;
        validMask(n,m) = true;
end

% Local cost matrix.
local = inf(n,m);

for i = 1:n
    for j = 1:m
        if ~validMask(i,j)
            continue;
        end

        delta = abs(x(i)-y(j))^p;
        local(i, j) = delta;
        
    end
end

% Dynamic programming.
D = inf(n,m);
pred = zeros(n,m,'uint8');

D(1,1) = local(1,1);

for i = 1:n
    for j = 1:m
        if (i == 1 && j == 1) || ~validMask(i,j)
            continue;
        end

        D(i, j) = local(i, j);
        candidates = [inf,inf,inf];

        if i > 1 && j > 1
            candidates(1) = D(i-1,j-1);
        end
        if i > 1
            candidates(2) = D(i-1,j);
        end
        if j > 1
            candidates(3) = D(i,j-1);
        end

        [best,k] = min(candidates);

        if isfinite(best)
            D(i,j) = D(i, j) + best;
            pred(i,j) = uint8(k);
        end
    end
end

if ~isfinite(D(n,m))
    error('No feasible path. Relax the constraint.');
end

% Backtrack to obtain optimal warping path.
i = n;
j = m;
pathXY = [i,j];

while i > 1 || j > 1
    switch pred(i,j)
        case 1
            i = i-1;
            j = j-1;
        case 2
            i = i-1;
        case 3
            j = j-1;
        otherwise
            error('Could not reconstruct DTW path.');
    end

    % pathXY(end+1,:) = [i,j]; %#ok<AGROW>
    pathXY = cat(1, pathXY, [i, j]);
end

pathXY = flipud(pathXY);

% Construct aligned signals.
xAligned = x(pathXY(:,1));
yAligned = y(pathXY(:,2));

distance = D(n,m)^(1/p);

if o.Normalize
    distance = distance/size(pathXY,1);
end

% Diagnostic information.
info.localCost = local;
info.cumulativeCost = D;
info.allowedCells = validMask;
info.pathLength = size(pathXY,1);
info.options = o;

end

