function [x_Area, Table_Area, indices_v_Full] = ...
    singlephaselin(busDataTable_pu_Area, branchDataTable_Area, v2_parent_Area, S_connection_Area, isLeaf_Area, ...
    Area, numAreas, graphDFS_Area, graphDFS_Area_Table, R_Area_Matrix, X_Area_Matrix, ...
    busesWithDERs_Area, lb_Q_onlyDERbuses_Area, ub_Q_onlyDERbuses_Area, itr, varargin)

 % Default values for optional arguments
    verbose = false;
    CVR = [0; 0];
    V_max = 1.05;
    V_min = 0.95;

    saveToFile = false;
    strArea = convert2doubleDigits(Area);
    fileExtension = ".txt";
    systemName = "ieee123";
    saveLocationName = "logfiles/";

    % Process optional arguments
    numArgs = numel(varargin);

    if mod(numArgs, 2) ~= 0
        error('Optional arguments must be specified as name-value pairs.');
    end
    
    validArgs = ["verbose", "CVR", "V_max", "V_min", "saveToFile", "saveLocation"];
    
    for i = 1:2:numArgs
        argName = varargin{i};
        argValue = varargin{i+1};
        
        if ~ischar(argName) || ~any(argName == validArgs)
            error('Invalid optional argument name.');
        end
        
        switch argName
            case "verbose"
                verbose = argValue;
            case "CVR"
                CVR = argValue;
            case "V_max"
                V_max = argValue;
            case "V_min"
                V_min = argValue;
            case 'saveToFile'
                saveToFile = argValue;
            case 'saveLocation'
                saveLocationName = argValue;
        end
    end

    saveLocationFilename = strcat(saveLocationName, systemName, "/numAreas_", num2str(numAreas), "/Aeq_beq_area", strArea, "_singlephaselin", fileExtension);
    
    fileOpenedFlag = false;
    
    if itr ~= 0 
        verbose = false;
    end

    if verbose && saveToFile && itr == 0 && Area == 2
        fileOpenedFlag = true;
        fid = fopen(saveLocationFilename, 'w');  % Open file for writing
    else
        verbose = false;
        fid = 1;
    end
    
    N_Area = length(busDataTable_pu_Area.bus);
    m_Area = length(branchDataTable_Area.fb);
    fb_Area = branchDataTable_Area.fb;
    tb_Area = branchDataTable_Area.tb;
    P_L_Area = busDataTable_pu_Area.P_L;
    Q_L_Area = busDataTable_pu_Area.Q_L;
    Q_C_Area = busDataTable_pu_Area.Q_C;
    P_der_Area = busDataTable_pu_Area.P_der;
    S_der_Area = busDataTable_pu_Area.S_der;

    if ~isLeaf_Area
        myfprintf(verbose, fid, "Area %d is NOT a leaf area, does have child areas.\n", Area);
        for j = 1:size(S_connection_Area, 1)
            [P_L_Area(end-j+1), Q_L_Area(end-j+1)] = deal(real(S_connection_Area(end-j+1)), imag(S_connection_Area(end-j+1)));
        end
    else
        myfprintf(verbose, fid, "Area %d does NOT have any child areas.\n", Area);
    end
    
    m_Area = N_Area - 1;
    indices_P = 1:N_Area-1;  %1:40
    indices_Q = indices_P + (N_Area - 1); %41:80
    % indices_l = indices_Q + m_Area; %81:120
    indices_v = indices_Q + 1 + m_Area; %122:161
    Table_Area = [graphDFS_Area_Table.fbus graphDFS_Area_Table.tbus indices_P' indices_Q' indices_v'];
    Table_Area_Table = array2table(Table_Area, 'VariableNames', {'fbus', 'tbus', 'indices_P', 'indices_Q', 'indices_v'});
    indices_v_Full = transpose( indices_v(1)-1:indices_v(end) ) ; %121:161 % voltage variables including parent node.
    
    fbus = graphDFS_Area_Table.fbus;
    tbus = graphDFS_Area_Table.tbus;
    % Initialization-
    
    CVR_P = CVR(1);                %% this will make the loads as constant power load
    CVR_Q = CVR(2);                %% this will make the loads as constant power load
    Aeq = zeros( 3*(N_Area-1), Table_Area_Table{end, end} ); %zeros(120, 121)
    beq = zeros( 3*(N_Area-1), 1); %zeros(120, 1)
    
    % A and b matrix formulation-
    
    for currentBusNum = 2 : N_Area
        childBusIndices = find(fbus == currentBusNum) ;
        parentIdx = find(tbus == currentBusNum) ;
        parentBusNum = fbus(parentIdx);
        siblingBusesIndices = find(fbus == parentBusNum);
        
        % Aeq formulations
        %indices_P equations
        Aeq(parentIdx, indices_P(parentIdx) ) = 1; 
        Aeq(parentIdx, indices_v(parentIdx) ) = -0.5 * CVR_P * P_L_Area(currentBusNum);
        
        %indices_Q equations
        Aeq( parentIdx + (N_Area-1), indices_Q(parentIdx) ) = 1;
        Aeq( parentIdx + (N_Area-1), indices_v(parentIdx) ) = -0.5 * CVR_Q * Q_L_Area(currentBusNum);
        
        % For nodes with child bus
        if ~isempty(childBusIndices)
            for currentSiblingIdx = 1 : length(childBusIndices)
                Aeq(parentIdx, Table_Area(childBusIndices(currentSiblingIdx),3)) =   - 1;   % for P
                Aeq(parentIdx+(N_Area-1),Table_Area(childBusIndices(currentSiblingIdx),4)) =  -  1;   % for indices_Q
            end
        end
        
        % V equations
        Aeq(parentIdx+2*(N_Area-1),indices_v(parentIdx))= 1;
        Aeq(parentIdx+2*(N_Area-1),indices_v_Full(siblingBusesIndices(1)))= -1;
        Aeq(parentIdx+2*(N_Area-1),Table_Area(parentIdx,3))= 2*(R_Area_Matrix(graphDFS_Area((parentIdx),1),graphDFS_Area((parentIdx),2)));
        Aeq(parentIdx+2*(N_Area-1),indices_Q(parentIdx))= 2*(X_Area_Matrix(graphDFS_Area((parentIdx),1),graphDFS_Area((parentIdx),2)));
        
        
        % beq Formulation
        beq(parentIdx)=(1-(CVR_P/2))*P_L_Area(currentBusNum)-P_der_Area(currentBusNum);
        beq(parentIdx+(N_Area-1)) =  (1-(CVR_Q/2))*Q_L_Area(currentBusNum)-Q_C_Area(currentBusNum);
        
    end
    
    % substation voltage equation
    Aeq(3*(N_Area-1)+1,indices_v_Full(1)) = 1;
    beq(3*(N_Area-1)+1) = v2_parent_Area;
    
    % DER equation addition
    for k22 = 1:size(busesWithDERs_Area,1)
        Aeq((Table_Area(busesWithDERs_Area(k22) == Table_Area(:,2),4)), end+1) = 1;
    end
    
    %
    
    if fileOpenedFlag
        fclose(fid);
    end
    Tnvar = size(Aeq,2);         % total number of variables
    
    % formation of objective function
    
    f = zeros(Tnvar,1);
    f(Table_Area(1,3)) = 0;
    
    lb(1) = 0;                  % this is to limit the power flow going reverse at the substation
    lb(2:2*(N_Area-1),1)= (-1500*ones(2*(N_Area-1)-1,1));
    lb(2*(N_Area-1)+1:3*(N_Area-1)+1,1)= ((V_min^2)*ones(N_Area,1));
    
    ub(1:2*(N_Area-1),1)= (1500*ones(2*(N_Area-1),1));
    ub(2*(N_Area-1)+1:3*(N_Area-1)+1,1)= (V_max^2*ones(N_Area,1));
    
    lb = [lb ;lb_Q_onlyDERbuses_Area];
    ub = [ub; ub_Q_onlyDERbuses_Area];
    
    options = optimoptions('intlinprog','Display','off');
    [x_Area, ~, ~, ~] = intlinprog(f, [], [], [], Aeq, beq, lb, ub, options);
    
    xIndices = 2*N_Area:3*N_Area-2;

    V2(Table_Area(:, 2), 1) = x_Area(xIndices);
    
    V2(1) = V_max^2;
    v2_Area = sqrt(V2);

end