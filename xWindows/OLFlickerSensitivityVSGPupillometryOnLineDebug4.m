% Windows client serving UDP communication requests from 
% ModulationTrialSequencePupillometryNulledOnLine.m (Mac)
% These two programs must be run in tanden to conduct the pupillometry experiments.
%
% 03/01/2016   NPC  Wrote it (by modifying OLFlickerSensitivityVSGpupillometry) 
% 03/04/2016   NPC  Added UDP communication tests
% 07/20/2016   NPC  Try/cath statment

function [data, params] = OLFlickerSensitivityVSGPupillometryOnLine

    % Housekeeping.
    clear; close all; clc

    % Ask if we want to save in Dropbox
    maxAttempts = 2;
    nSecsToSave = 5;
    fprintf('\n*********************************************');
    fprintf('\n*********************************************\n');
    saveDropbox = GetWithDefault('Save into Dropbox folder?', 1);
    
    
    % Initialize Cambridge Researsh System and Other Neccessary Variables
    % Global CRS gives us access to a cell structure of the Video Eye Tracker's
    % variables.  Load constants creates this cell structure
    global CRS;
    if isempty(CRS)
        crsLoadConstants;
    end

    % vetClearDataBuffer clears values that may have been previously recorded
    vetClearDataBuffer;

    % vetLoadCalibrationFile loads a calibration file that was created using the
    % provided CRS application called Video Eye Trace.  This calibration file
    % correlates a subject's pupil position with a focal point in visual space.
    % The .scf file is needed in order for the Eye tracker to intialize and
    % function properly.
    calFilePath = 'C:\Users\melanopsin\Documents\MATLAB\Toolboxes\PupillometryToolbox\xWindows\subjectcalibration_current.scf';
    vetLoadCalibrationFile(calFilePath);

    % The way CRS setup the Eye Tracker, we must set a stimulus device, although
    % in reality, our stimulus device is the OneLight machine. For the sake of
    % initialization, we must tell the Video Eye Tracker that the stimulus will
    % be presented on a screen connected through a VGA port.
    vetSetStimulusDevice(CRS.deVGA);

    % vetSelectVideoSource prepares the framegrabber (PICOLO card) to receive
    % data from a connected video eye tracker.  Our model of the eye tracker is
    % labeled as the .vsCamera (a CRS convention/nomenclature)
    if vetSelectVideoSource(CRS.vsCamera) < 0
        error('*** Video source not selected.');
    end
    
    
    % Add path to brainard lab toolbox to access the OLVSGCommunicator class
    addpath(genpath('C:\Users\melanopsin\Documents\MATLAB\Toolboxes\BrainardLabToolbox'));
    
    macHostIP = '128.91.12.106';
    winHostIP = '128.91.12.103';
    udpPort = 2007;

    % === NEW ======  Instantiate a OLVSGcommunicator object ==============
    VSGOL = OLVSGcommunicator( ...
        'signature', 'WindowsSide', ...  % a label indicating the host, used to for user-feedback
          'localIP', winHostIP, ...    % required: the IP of this computer
         'remoteIP', macHostIP, ...    % required: the IP of the computer we want to conenct to
          'udpPort', udpPort, ...      % optional, with default value: 2007
        'verbosity', 'max' ...        % optional, with default value: 'normal', and possible values: {'min', 'normal', 'max'},
    );


    % encapsulate everything in a master try/catch closure
    try 
        
        % === NEW ====== Wait for ever to receive the Wake Up signal from Mac ================
        fprintf('\n<strong>Run OLFlickerSensitivity on Mac and select protocol... </strong>\n');
        VSGOL.receiveParamValue(VSGOL.WAIT_STATUS, ...
            'expectedParamValue', 'Wake Up', ...
            'timeOutSecs', Inf, 'consoleMessage', 'Hey Mac, is there anybody out there?');
        % === NEW ====== Receiving the Wake Up signal from Mac ================

        % === NEW ====== Wait for ever to receive a signal indicating whether we 
        % will be testing communication delay between Mac and Windows
        runCommTest = VSGOL.receiveParamValue(VSGOL.UDPCOMM_TESTING_STATUS, ...
            'timeOutSecs', Inf, 'consoleMessage', 'Hey Mac, will we be running UDPcomm delay experiments today?');

        if (runCommTest)
            runCommunicationTests(VSGOL);
        end 
    
        % === NEW ====== Get param values for labeled param names ==================
        protocolNameStr = VSGOL.receiveParamValue(VSGOL.PROTOCOL_NAME,       'timeOutSecs', Inf, 'consoleMessage', 'receiving protocol name');
        obsID           = VSGOL.receiveParamValue(VSGOL.OBSERVER_ID,         'timeOutSecs', 4, 'consoleMessage', 'receiving observer ID');
        obsIDAndRun     = VSGOL.receiveParamValue(VSGOL.OBSERVER_ID_AND_RUN, 'timeOutSecs', 4, 'consoleMessage', 'receiving observer ID and run');
        % === NEW ====== Get param values for labeled param names ==================

        % Assemble dropbox paths
        if saveDropbox
            dropboxPath = 'C:\Users\melanopsin\Dropbox (Aguirre-Brainard Lab)\MELA_data';
            savePath = fullfile(dropboxPath, protocolNameStr, obsID, datestr(now, 'mmddyy'), 'MatFiles', obsIDAndRun);
        else
            expPath = fileparts(mfilename('OLFlickerSensitivityVSGPupillometry.m'));
            savePath = fullfile(expPath,  protocolNameStr, obsID, obsIDAndRun);
        end
        if ~isdir(savePath)
            mkdir(savePath);
        end

        % === NEW ====== Get param values for labeled param names ==================
        nTrials         = VSGOL.receiveParamValue(VSGOL.NUMBER_OF_TRIALS,  'timeOutSecs', 4, 'consoleMessage', 'receiving number of trials');
        startTrialNum   = VSGOL.receiveParamValue(VSGOL.STARTING_TRIAL_NO, 'timeOutSecs', 4, 'consoleMessage', 'receiving which trial to start');
        offline         = VSGOL.receiveParamValue(VSGOL.OFFLINE,           'timeOutSecs', 4, 'consoleMessage', 'receivingVSGOfflineMode');
        % === NEW ====== Get param values for labeled param names ==================

        if (offline)
            % Figure out paths.

            % Set up the file name of the output file
            saveFile = fullfile(savePath, obsIDAndRun);

            %error('offline mode not implemented at this time.  There is unfinished offline code present in this state of the routine.  This error will be removed once the offline code is completed at a future time.');
        end

        % We start tracking here
        vetStartTracking;
        
        % ========================= Pre-trial video recording ==========================
        try
            fprintf('\nRecording pre-trial loop diagnostics video... ');
            vetStartRecordingToFile(fullfile([saveFile '_diagnostics_PreTrialLoop.cam']));
            pause(nSecsToSave);
            vetStopRecording;
            fprintf('Done.\n');

            % Let the Mac know we are done (successfully) with the post-trial diagnostics video recording
            VSGOL.sendParamValue({VSGOL.DIAGNOSTIC_VIDEO_RECORDING_STATUS, 'sucessful'}, 'timeOutSecs', 4);

        catch err
            % Let the Mac know we are done (successfully) with the post-trial diagnostics video recording
            VSGOL.sendParamValue({VSGOL.DIAGNOSTIC_VIDEO_RECORDING_STATUS, 'not sucessful'}, 'timeOutSecs', 4);
            rethrow(err);
        end
        
        vetCreateCameraScreen;
        
        %% Loop over trials
        for i = startTrialNum:nTrials
            
            checkTrials = 1:6:100;
            %checkTrials = [1 3 5];
            if ismember(i, checkTrials);
            %% Initializating variables
            params.run = false;

            %% Check if we are ready to run
            checkCounter = 0;
            while (params.run == false)
                checkCounter = checkCounter + 1;

                % === NEW ====== Wait for ever to receive the userReady status ==================
                VSGOL.receiveParamValue(VSGOL.USER_READY_STATUS,  ...
                    'expectedParamValue', 'user ready to move on', ...
                    'timeOutSecs', Inf, 'consoleMessage', 'Is user ready?');
                % === NEW ====== Wait for ever to receive the userReady status ==================
                fprintf('>>> Check %g\n', checkCounter);

                if checkCounter <= maxAttempts
                    % ==== NEW ===  Send user ready status ========================
                    VSGOL.sendParamValue({VSGOL.USER_READY_STATUS, 'continue'}, 'timeOutSecs', 8);
                    % =============================================================

                    params.run = VSGOLEyeTrackerCheck(VSGOL);
                else
                    % ==== NEW ===  Send user ready status ========================
                    VSGOL.sendParamValue({VSGOL.USER_READY_STATUS, 'abort'}, 'timeOutSecs', 8);
                    % =============================================================

                    fprintf('>>> Could not acquire good tracking after %g attempts.\n', maxAttempts);
                    fprintf('>>> Saving %g seconds of diagnostic video on the hard drive.\n', nSecsToSave);

                    vetStartTracking;
                    vetStartRecordingToFile(fullfile([saveFile '_' num2str(i, '%03.f') '_diagnostics.cam']));
                    pause(nSecsToSave);
                    vetStopRecording;
                    vetStopTracking;
                    abortExperiment = true;
                    params.run = true;
                end
            end % while (params.run == false)
            end
            
            % Reset the buffer
            vetClearDataBuffer;

            % Get the 'Go' signal
            % === NEW ====== Wait for ever to receive the StartTracking signal ==================
            VSGOL.receiveParamValue(VSGOL.EYE_TRACKER_STATUS,  ...
                'expectedParamValue', 'startTracking', ...
                'timeOutSecs', Inf, 'consoleMessage', 'Start tracking?');
            % === NEW ====== Wait for ever to receive the START signal ==================

            % Check the 'stop' signal from the Mac
            % === NEW === Wait for ever to receive the stopTracking signal, then send the trial outcome ==================
            VSGOL.receiveParamValueAndSendResponse(...
                {VSGOL.EYE_TRACKER_STATUS, 'stopTracking'}, ...                  % expected param name and value
                {VSGOL.TRIAL_OUTCOME, sprintf('Trial %f has ended!\n', i)}, ...  % the response to be sent
                'timeOutSecs', Inf, 'consoleMessage', 'Stop tracking?');
            % === NEW === Wait for ever to receive the stopTracking signal, then send the trial outcome ==================

            % Get all data from the buffer
            pupilData = vetGetBufferedEyePositions;

            if offline
                % Stop the tracking
                vetStopRecording;
            end

            % Get the transfer data
            goodCounter = 1;
            badCounter = 1;
            clear transferData;
            for jj = 1 : length(pupilData.timeStamps)
                if ((pupilData.tracked(jj) == 1)) %&& VSGOLIsWithinBounds(radius, origin, pupilData.mmPositions(jj,:)))
                    % Save the pupil diameter and time stamp for good data
                    % Keep data for checking plot
                    goodPupilDiameter(goodCounter) = pupilData.pupilDiameter(jj);
                    goodPupilTimeStamps(goodCounter) = pupilData.timeStamps(jj);

                    %Save the data as strings to send to the Mac
                    tempData = [num2str(goodPupilDiameter(goodCounter)) ' ' num2str(goodPupilTimeStamps(goodCounter)) ' 0 ' '0'];
                    transferData{jj} = tempData;

                    goodCounter = goodCounter + 1;
                else
                    % Save the time stamp for bad data
                    % Keep data for checking plot
                    badPupilTimeStamps(badCounter) = pupilData.timeStamps(jj);

                    %Send the timestamps of the interruptions
                    tempData = ['0' ' 0 ' '1 ' num2str(badPupilTimeStamps(badCounter))];
                    transferData{jj} = tempData;

                    badCounter = badCounter + 1;
                end
            end

            % Start the file transfer

            numDataPoints = length(transferData);
            clear diameter;
            clear time;
            clear time_inter;

            if offline

                % Wait for mac to tell us to start saving data
                % === NEW ====== Wait for ever to receive the StartTracking signal ==================
                VSGOL.receiveParamValue(VSGOL.EYE_TRACKER_STATUS,  ...
                    'expectedParamValue', 'startSavingOfflineData', ...
                    'timeOutSecs', Inf, 'consoleMessage', 'Start saving offline data?');
                % === NEW ====== Wait for ever to receive the StartTracking signal ==================

                try  % Nicolas' addition #1
                    
                    good_counter = 0;
                    interruption_counter = 0;

                    % Iterate over the data points
                    for j = 1:numDataPoints
                        parsedline = allwords(transferData{j}, ' ');
                        diam = str2double(parsedline{1});
                        ti = str2double(parsedline{2});
                        isinterruption = str2double(parsedline{3});
                        interrupttime = str2double(parsedline{4});
                        if (isinterruption == 0)
                            good_counter = good_counter+1;
                            diameter(good_counter) = diam;
                            time(good_counter) = ti;
                        elseif (isinterruption == 1)
                            interruption_counter = interruption_counter + 1;
                            time_inter(interruption_counter) = interrupttime;
                        else
                            fprintf(2,'isinterruption variable is %d\n', isinterruption);
                        end
                    end
                    
                    if ~exist('diameter', 'var')
                        diameter = [];
                        fprintf(2,'diameter variable does not exist\n');
                    end

                    if ~exist('time', 'var')
                        time = [];
                        fprintf(2,'time variable does not exist\n');
                    end

                    if ~exist('time_inter', 'var')
                        time_inter = [];
                        fprintf(2,'time_inter variable does not exist\n');
                    end

                    %average_diameter = mean(diameter)*ones(size(time));

                    % Assign what we obtain to the data structure.
                    dataStruct.diameter = diameter;
                    if isempty(time)
                        dataStruct.time = time;
                        dataStruct.time_inter = time_inter;
                    else
                        dataStruct.time = time-time(1);
                        dataStruct.time_inter = time_inter-time(1);
                    end
                    %dataStruct.average_diameter = average_diameter;

                    dataRaw = transferData;
                    save([saveFile '_' num2str(i, '%03.f') '.mat'], 'dataStruct', 'dataRaw', 'pupilData');

                % beginning of Nicolas' addition #2
                catch err
                    fprintf('Windows error during the iteration over data points and saving to %s (error: %s)\n', saveFile, err.message);
                    rethrow(err)
                end
                % end of Nicolas' addition #2
                
                % === NEW ====== Tell mac we are all done saving offline data ==================
                VSGOL.sendParamValue(...
                    {VSGOL.EYE_TRACKER_STATUS,  'finishedSavingOfflineData'}, ...
                    'timeOutSecs', 8, 'consoleMessage', 'Informing Mac we ended saving offline data' ...
                );
            else

                % === NEW ====== Wait for ever to receive a 'begin transfer' signal and respond to it ==================
                VSGOL.receiveParamValueAndSendResponse(...
                    {VSGOL.DATA_TRANSFER_STATUS, 'begin transfer'}, ...  % received from mac
                    {VSGOL.DATA_TRANSFER_STATUS, 'begin transfer'}, ...  % transmitted back
                    'timeOutSecs', Inf, ...
                    'consoleMessage', 'Begin data transfer?' ...
                );
                % === NEW ====== Wait for ever to receive a 'begin transfer' signal and respond to it ==================

                % ==== NEW ===  Send the number of data points to be transferred ===
                VSGOL.sendParamValue({VSGOL.DATA_TRANSFER_POINTS_NUM, numDataPoints}, ...
                    'timeOutSecs', 8, 'consoleMessage', sprintf('Informing Mac about number of data points (%d)', numDataPoints));
                % ==== NEW ===  Send the number of data points to be transferred ===

                % Iterate over the data
                for kk = 1:numDataPoints

                    % === NEW Wait for ever to receive request to transfer data for point kk, then send that data over
                    VSGOL.receiveParamValueAndSendResponse(...
                        {VSGOL.DATA_TRANSFER_REQUEST_FOR_POINT, kk}, ...  % received trasnfer request for data point kk 
                        {VSGOL.DATA_FOR_POINT, transferData{kk}}, ...     % transmit back the data for point kk
                        'timeOutSecs', Inf ...
                    );
                    % === NEW Wait for ever to receive request to transfer data for point kk, then send that data over

                end % kk

                % Finish up the transfer
                VSGOL.receiveParamValue(VSGOL.DATA_TRANSFER_STATUS, ...
                    'expectedParamValue', 'end transfer', ...
                    'consoleMessage', sprintf('Data for trial %d transfered. End data transfer?', i));
            end

            %% After the trial, plot out a trace of the data. This is presumably to make sure that everything went ok.
            % Calculates average pupil diameter.
            % meanPupilDiameter = mean(goodPupilDiameter);

            %     % Creates a figure with pupil diameter and interruptions over time. Also
            %     % displays the average pupil diameter over time.
            %     plot(goodPupilTimeStamps/1000,goodPupilDiameter,'b')
            %     hold on
            %     plot([goodPupilTimeStamps(1) goodPupilTimeStamps(2)]/1000, [meanPupilDiameter meanPupilDiameter], 'g')
            %     plot(badPupilTimeStamps/1000, zeros(size(badPupilTimeStamps)),'ro');

        end % for i
        
            % Stop tracking
            vetStopTracking;
    
        % ========================= Post-trial video recording ==========================
        try
            fprintf('\nRecording post-trial loop diagnostics video... ');
            vetStartTracking;
            vetStartRecordingToFile(fullfile([saveFile '_diagnostics_PostTrialLoop.cam']));
            pause(nSecsToSave);
            vetStopRecording;
            vetStopTracking;
            fprintf('Done.\n');

            % Let the Mac know we are done (sucessfully) with the post-trial diagnostics video recording
            VSGOL.sendParamValue({VSGOL.DIAGNOSTIC_VIDEO_RECORDING_STATUS, 'sucessful'}, 'timeOutSecs', 4);

        catch err
            % Let the Mac know we are done (un-sucessfully)  with the post-trial diagnostics video recording
            VSGOL.sendParamValue({VSGOL.DIAGNOSTIC_VIDEO_RECORDING_STATUS, 'not sucessful'}, 'timeOutSecs', 4);
        end

        % Close the UDP connection
        VSGOL.shutDown();

        fprintf('*** Program completed successfully.\n');
        
    catch err
        err.message
        % ==== NEW ===  Tell mac to abort due to fatal error on our part ===
        VSGOL.sendParamValue({VSGOL.ABORT_MAC_DUE_TO_WINDOWS_FAILURE, sprintf('Mac, please abort. Windows experienced the following error:  %s).', err.message)}, 'timeOutSecs', 4);
        % ==== NEW ===  Tell mac to abort due to fatal error on our part ===
                
        % Close the UDP connection
        VSGOL.shutDown();
        
        rethrow(err);
    end
end

function runCommunicationTests(VSGOL)

    % Wait to receive the UDPtestRepeatsNum
    UDPtestRepeatsNum = VSGOL.receiveParamValue(VSGOL.UDPCOMM_TESTING_REPEATS_NUM, ...
       'timeOutSecs', Inf, 'consoleMessage', 'receiving number of UDPcommunication test repeats');

    % Test 1. Mac->Windows: Sending a param value - no value checking
    for kRepeat = 1:UDPtestRepeatsNum
        VSGOL.receiveParamValue(VSGOL.UDPCOMM_TESTING_SEND_PARAM, ...
            'timeOutSecs', 2,  'consoleMessage', 'Test 1: Mac -> Windows, send param');
    end

    % Test 2. Mac <- Windows: Sending a param value - no value checking
    for kRepeat = 1:UDPtestRepeatsNum
        VSGOL.sendParamValue({VSGOL.UDPCOMM_TESTING_RECEIVE_PARAM, kRepeat*10-2}, ...
            'timeOutSecs', 2.0, 'maxAttemptsNum', 1, 'consoleMessage',  'Test 2: Mac <- Windows, receive param');
    end

    % Test 3. Mac->Windows: Sending a param value and wait for response
    for kRepeat = 1:UDPtestRepeatsNum
        VSGOL.receiveParamValueAndSendResponse(...
            {VSGOL.UDPCOMM_TESTING_SEND_PARAM_WAIT_FOR_RESPONSE, 'validCommand1'}, ...         % received from mac
            {VSGOL.UDPCOMM_TESTING_SEND_PARAM_WAIT_FOR_RESPONSE, 'validCommand2'}, ...        % transmitted back
            'timeOutSecs', Inf, ...
            'consoleMessage', 'Test 3: Mac -> Windows, send param, validate value, wait for response' ...
        );
    end

    % Now wait for Mac to tell us to proceed with the experiment
    VSGOL.receiveParamValue(VSGOL.WAIT_STATUS, ...
        'expectedParamValue', 'Proceed with experiment', ...
        'timeOutSecs', Inf, 'consoleMessage', 'Hey Mac, should I proceed with the experiment?');
end
        
function canRun = VSGOLEyeTrackerCheck(VSGOL)

    % === NEW ====== Wait for ever to receive the eye tracker status ==================
   	checkStart = VSGOL.receiveParamValue(VSGOL.EYE_TRACKER_STATUS,  ...
        'timeOutSecs', 2, 'consoleMessage', 'Start checking eye tracking ?');
    % === NEW ====== Wait for ever to receive the eye tracker status ==================
    
    WaitSecs(1);
    if (strcmp(checkStart,'startEyeTrackerCheck'))
        
        try
            fprintf('*** Start tracking...\n')
            vetClearDataBuffer;
            timeCheck = 5;
            tStart = GetSecs;
            
            while (GetSecs - tStart < timeCheck)
                % Collect some checking data
            end
            fprintf('*** Tracking finished \n')
            checkData = vetGetBufferedEyePositions;
            sumTrackData = sum(checkData.tracked);
            fprintf('*** Number of checking data points %d\n',sumTrackData)

            % ==== NEW ===  Send eye tracker status = startEyeTrackerCheck ========
            VSGOL.sendParamValue({VSGOL.EYE_TRACKER_DATA_POINTS_NUM, sumTrackData}, ...
                'timeOutSecs', 8.0, 'maxAttemptsNum', 3);
            % ==== NEW ============================================================

            % === NEW ====== Wait for ever to receive the new eye tracker status ==================
            trackingResult = VSGOL.receiveParamValue(VSGOL.EYE_TRACKER_STATUS,  ...
                'timeOutSecs', Inf, 'consoleMessage', 'Did we track OK?');
            if (strcmp(trackingResult, 'isNotTracking'))
                canRun = false;
            else
                canRun = true;
            end
            % === NEW ====== Wait for ever to receive the new eye tracker status ==================
            
        catch err
            % ==== NEW ===  Tell mac to abort due to fatal error on our part ===
            VSGOL.sendParamValue({VSGOL.ABORT_MAC_DUE_TO_WINDOWS_FAILURE, sprintf('Mac, please abort. Windows (VSGOLEyeTrackerCheck) experienced the following error:  %s).', err.message)}, 'timeOutSecs', 4);
            % ==== NEW ===  Send the number of data points to be transferred ===

            % Close the UDP connection
            VSGOL.shutDown();

            rethrow(err);
        end
    end
end