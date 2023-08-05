yNodes = struct();
yNodes.Names = ["P_ij", "Q_ij", "S_ij", "l_ij", "v_j", "qD_j", "B_j", "Pc_j", "Pd_j", "qB_j"].';
yNodes.VarNames = ["P_ij", "Q_ij", "S_ij", "l_ij", "v_j", "qD_j", "B_j", "Pc_j", "Pd_j", "qB_j"].';
yNodes.Units = ["kW", "kVAr", "kVA", "pu", "pu", "kVAr", "kWh", "kW", "kW", "kVAr"].';
yNodes.FullNames = ["Branch Real Power Flow", "Branch Reactive Power Flow", ...
    "Branch Apparent Power Flow", "Branch Squared Current Flow", "Bus Squared Voltage", ...
    "DER Reactive Power", "Battery State of Charge", "Battery Average Charging Power", ...
    "Battery Average Discharging Power", "Battery Reactive Power"].';
yNodes.FigureNames = ["branchRealPowerFlow", "branchReactivePowerFlow", ...
    "branchApparentPowerFlow", "branchSquaredCurrentFlow", "busSquaredVoltage", ...
    "DERReactivePower", "batterySOC", "batteryChargingPower", "batteryDischargingPower", ...
    "batteryReactivePower"].';
yNodes.Legends = ["P_{ij}", "Q_{ij}", "S_{ij}", "l_{ij}", "v_j", "q_{D_j}", ...
    "B_j", "P_{c_j}", "P_{d_j}", "q_{B_j}"].';
yNodes.yLabelNames = strcat(yNodes.Legends, ' \thinspace [', yNodes.Units, ']');
yNodesTable = struct2table(yNodes);

% Display the table
disp(yNodesTable);
writetable(yNodesTable, strcat("plottingSpecifications\", "yNodesTable", ".csv"))
