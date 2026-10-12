clear; clc;
% close all


%%

dataFolderSourceString = '/Users/aniketmandal/Documents/MATLAB/SupiLabProgramsDatas/ArtifactRejection/data';

stimDataContents = load(fullfile(dataFolderSourceString, 'amp64.mat'));
stimData = stimDataContents.rawData;

noStimDataContents = load(fullfile(dataFolderSourceString, 'amp0.mat'));
noStimData = noStimDataContents.rawData;

timeFileContents = load(fullfile(dataFolderSourceString, 'times.mat'));
timeVals = timeFileContents.timeValsRaw;

fs = 30000;

% align stimData before using
[~, stimData] = alignStimStartPosns(stimData, timeVals);


%%

artifactRejectionGUI(stimData, timeVals, fs);

