clear; clc;
% close all


%%

dataFolderSourceString = '/Users/aniketmandal/Documents/MATLAB/SupiLabProgramsDatas/ArtifactRejection/data';

stimDataContents = load(fullfile(dataFolderSourceString, 'amp64.mat'));
stimData = stimDataContents.rawData;

% align before using
stimData = alignStimStartPosns(stimData, timeVals);

noStimDataContents = load(fullfile(dataFolderSourceString, 'amp0.mat'));
noStimData = noStimDataContents.rawData;

timeFileContents = load(fullfile(dataFolderSourceString, 'times.mat'));
timeVals = timeFileContents.timeValsRaw;

fs = 30000;


%%

artifactRejectionGUI(stimData, timeVals, fs);

spikeLocs = [-0.01177 -0.0105; 0.03837 0.0391; 0.08853 0.0891; 0.138535 0.1391; 0.1884 0.189; ...
    0.238367 0.239; 0.28827 0.28896];