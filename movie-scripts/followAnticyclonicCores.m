function path = followAnticyclonicCores(candidates, time, domainKm, gridSpacingKm, options)
% Associate negative vorticity minima across consecutive saved snapshots.
%
% Each candidate row is [xKm yKm localizationVorticity ix iy iz]. Initialize at the most
% negative candidate, then choose the nearest candidate in periodic distance.
% Vorticity breaks exact distance ties, but a distant, stronger minimum cannot
% steal the track. A speed limit plus one grid-cell diagonal bounds each step.
% If the core is lost, the remaining path is undefined; no reacquisition occurs.
%
% Ambiguity is flagged when the two nearest eligible minima differ in distance
% by no more than one grid-cell diagonal. The flag does not smooth the path.
%
% - Topic: Track the anticyclonic core
% - Declaration: path = followAnticyclonicCores(candidates,time,domainKm,gridSpacingKm,options)
% - Parameter candidates: one cell per time, containing negative local minima
% - Parameter time: strictly increasing saved times, in seconds
% - Parameter domainKm: periodic horizontal domain lengths, in km
% - Parameter gridSpacingKm: horizontal grid spacings, in km
% - Parameter maximumSpeed: maximum translation speed in m/s; default 0.25
% - Returns path: selected candidate rows, unwrapped coordinates, steps, and status flags
arguments (Input)
    candidates (:,1) cell
    time (:,1) double {mustBeFinite}
    domainKm (1,2) double {mustBeFinite,mustBePositive}
    gridSpacingKm (1,2) double {mustBeFinite,mustBePositive}
    options.maximumSpeed (1,1) double {mustBeFinite,mustBePositive} = 0.25
end
arguments (Output)
    path (1,1) struct
end
if numel(candidates) ~= numel(time) || isempty(time) || any(diff(time) <= 0)
    error("EddyTide:InvalidTrackingTimes","Provide one candidate array per strictly increasing saved time.")
end
for iTime = 1:numel(time)
    c = candidates{iTime};
    if size(c,2) ~= 6 || any(~isfinite(c),"all") || any(c(:,3) >= 0)
        error("EddyTide:InvalidCoreCandidates","Candidate arrays must have six finite columns and negative normalized vorticity.")
    end
end

nTime = numel(time);
selected = nan(nTime,6);
unwrappedKm = nan(nTime,2);
stepKm = nan(nTime,1);
stepLimitKm = [0; options.maximumSpeed*diff(time)/1000 + norm(gridSpacingKm)];
status = repmat("lost",nTime,1);
eligibleCount = zeros(nTime,1);
runnerUpDistanceKm = nan(nTime,1);
candidateIndex = nan(nTime,1);
for iTime = 1:nTime
    c = candidates{iTime};
    if isempty(c)
        break
    end
    if iTime == 1
        [~,iCore] = min(c(:,3));
        selected(iTime,:) = c(iCore,:);
        unwrappedKm(iTime,:) = c(iCore,1:2);
        stepKm(iTime) = 0;
        status(iTime) = "seed";
        eligibleCount(iTime) = 1;
        candidateIndex(iTime) = iCore;
        continue
    end
    displacement = mod(c(:,1:2)-selected(iTime-1,1:2)+domainKm/2,domainKm)-domainKm/2;
    distanceKm = vecnorm(displacement,2,2);
    eligible = find(distanceKm <= stepLimitKm(iTime));
    eligibleCount(iTime) = numel(eligible);
    if isempty(eligible)
        break
    end
    [~,order] = sortrows([distanceKm(eligible),c(eligible,3)],[1 2]);
    iCore = eligible(order(1));
    selected(iTime,:) = c(iCore,:);
    candidateIndex(iTime) = iCore;
    unwrappedKm(iTime,:) = unwrappedKm(iTime-1,:) + displacement(iCore,:);
    stepKm(iTime) = distanceKm(iCore);
    status(iTime) = "ok";
    if numel(order) > 1
        runnerUpDistanceKm(iTime) = distanceKm(eligible(order(2)));
        if runnerUpDistanceKm(iTime)-stepKm(iTime) <= norm(gridSpacingKm)
            status(iTime) = "ambiguous";
        end
    end
end
path = struct(selected=selected,unwrappedKm=unwrappedKm,stepKm=stepKm,stepLimitKm=stepLimitKm,status=status,eligibleCount=eligibleCount,runnerUpDistanceKm=runnerUpDistanceKm,candidateIndex=candidateIndex);
end
