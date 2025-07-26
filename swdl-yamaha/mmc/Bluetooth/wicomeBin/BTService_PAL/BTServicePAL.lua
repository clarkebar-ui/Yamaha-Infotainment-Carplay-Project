--[[
	-- Project Adaptation Layer for the re-incarnated Bluetooth Service
	-- Author: Bluetooth Team
	-- Version: 19
]]--

--local variables

local config_filepath = "/fs/mmc0/Bluetooth/wicomeConf/BTServiceCore.cfg"

local service = require "service"
local btcore = require "btcore"
local json = require "json"
local timer = require "timer"

TRACE_CONSOLE = 1
TRACE_TRACECLIENT = 2

local traceClient = require "trace"
local traceScope = traceClient.scope("BtPAL_trace")
local mode = TRACE_TRACECLIENT

local bluetoothServiceName = "com.harman.service.BluetoothService"
local framService = "com.harman.service.PersistentKeyValue"
local databaseServiceName = "com.harman.service.DatabaseService"
local OnOffService = "com.harman.service.YAMAHAOnOff"

--Audio Manager
local audioManager = "com.harman.service.AudioManager"

--psse Control
local psseControlServiceName = "com.harman.service.psseControlService"

local handsfree_Scenario = "Handsfree"

local handsFreeMode = false                      -- Variable to store status of HandsFree Mode.
-- True if Audio is with HU, False if Audio with phone(Private mode).
local localDialing = false                       -- Set to true if a dialing scenario was initiated locally, so that audio can be routed.

local audioStatus = false                        -- Status of audio (SCO connection)                                             

-- THis flag indicates Call is not idle instead is eitHer witH pHone or witH HU
local callStateNotIdle = false

--This variable stores audio request status for Bluetooth call.
local audioRequestStatus = "NOT_REQUESTED" --Possible status: "NOT_REQUESTED", "REQUESTED", "GRANTED", "SUSPENDED"
local micRequestStatus   = "NOT_REQUESTED" --Possible status: "NOT_REQUESTED", "REQUESTED", "GRANTED"
local audioInfoSource    = "phone" 	       --Possible status: "phone", "phone_vr"
local hfmSourceStatus = false

--This variable is used to indicate whether we have to play default ring tone in case of incoming call w/o inband ring support.
local playDefaultRing   = false
local playDefaultRingID = 0
local ringToneDone      = false                 --Indicates that the incoming call was answered, so don't play ringtone

-- This flag is needed for mic availability.
local isMicAvaliable = false

-- This variable stores the power mode of system
local currentPowerMode = 0
local ignitionFalseValue = false

--- For turning on bluetooth temporarily to delete paired device list
local tempBluetoothOn = false
local bluetoothStatus = false

local linkQualityVal_New = -128
local linkQualityVal_Old = -128
local timerHandler = nil
--local timerHandlerAutoConnection = nil
local timerStartedStatus = false
local timerValue = 5000
--local retryTime_AutoConnection = 30000
local sendLinkQuality = false

local localAutoConnectionStatus = true
local localCurrentRingtoneSetting = 1	-- 1 -> System Ringtone , 2 -> Phone Ringtone, 3 -> No Ringtone
local localCurrentMasterRingtoneSetting = 1 -- 1 -> Phone Ringtone Enabled, 2 -> Phone Ringtone Disabled,
local ringtoneHandler = false

-- Pandora multi profile connection handling
local isSPPConnected = false;
A2DP_SOURCE	= "A2DP_SOURCE"
SPP_PANDORA = "SPP_PANDORA"
SPP_IAP = "SPP_IAP_Iphone"
local ignoreSPPSignalDeviceAddr
local ignoreSPPSignalServiceName
local connectedSPPDeviceAddr
local connectedSPPServiceName
-- Keep track of A2DP connections
local isA2DPConnectionPending = false;
local isA2DPConnected = true;
local A2DPDeviceAddr
-- pend SPP connection request till the current A2DP request is completed
-- Fix for pandora going to bad state when SPP is connected before A2DP
local pendSPPRequestToBeSent = false;
local pendIAPRequestToBeSent = false;
local pendSPPDeviceAddr
local pendIAPDeviceAddr
local sendSPPRequestAtBonding = true;
--<<==--------------------------------------
local methods = {}
local bluetoothService
local encode = json.encode
local decode = json.decode

local framAvailableSubscription

-- This flag is needed as old service is not calling resume call to activate held call
local heldCall = false
local dialedCallInfo = nil
local callInfo = {}

-- Timeout value for device discoverable ON. The device would be discoverable for this much duration once set to discoverable mode.
local DEV_DISCOVERABLE_ON_TIMEOUT = 180

-- Call state
CALL_STATE_TERMINATED = "CALL_STATE_TERMINATED"
CALL_STATE_IDLE = "CALL_STATE_IDLE"
CALL_STATE_ONHOLD = "CALL_STATE_ONHOLD"
CALL_STATE_DIALING = "CALL_STATE_DIALING"

dummyRes = {code = 14,description = "Default Error"}
successRes = {code = 0,description = "success"}

function emit(signal,params)
	service.emit(bluetoothService, signal, params)
end

local function trace(...)
   local printResult = ""
   for i=1, #arg do
      printResult = printResult .. tostring( arg[i] )
   end
   if mode == TRACE_TRACECLIENT then
      traceScope:msg(printResult)
   else
      print(printResult)
   end
end

local function standardResponse(context, replyExpected)
    local response
   	if replyExpected then
    	function response(code, description)
       		service.returnResult(context, {code = code, description = description})
		end
	else
		service.freeReqContext(context)
	end
    return response
end

local function standardResponseWithReason(context, replyExpected)
	local response
	if replyExpected then
		function response( code, description,reason )
			service.returnResult ( context, {code = code, description = description ,reason = reason} )
		end
	else
		service.freeReqContext(context)
	end
	return response
end

-- Check and raise the pending SPP requests
local function checkPendingSPPConnection( )
	trace("BT-PAL - Determing pending SPP requests ")
	if ( true == pendSPPRequestToBeSent ) then 
		trace("BT-PAL - Initiating previously pending SPP request")
		local response
		btcore.startServiceConnection(response, pendSPPDeviceAddr, SPP_PANDORA) 
		pendSPPRequestToBeSent = false
	end 
	
	if ( true == pendIAPRequestToBeSent ) then
		trace("BT-PAL - Initiating previously pending IAP request")
		local response
		btcore.startServiceConnection(response, pendIAPDeviceAddr, SPP_IAP) 
		pendIAPRequestToBeSent = false
	end
end

-----------------------------------------------------------------------
-- event handlers

local events = {}

local function processEvent(event, ...)
	local handler = events[event]
	if handler then
		handler(...)
	else
		trace("BT-PAL no handler for event", event)
	end
end

function events.batteryCharge(level, bdAddr)
	emit("batteryCharge", {level = level})
end

function events.bluetoothStatus(status)
 if not tempBluetoothOn then
 	trace("BT-PAL - Bluetooth actual status")
	bluetoothStatus = status
	emit("bluetoothStatus", {status = status})
	local result
	if (status == true) then
		btcore.setEyesFree(result, true)
	else
		btcore.setEyesFree(result, false)
	end
  else
	  trace("BT-PAL - Bluetooth temporary status")
	  if (status == true) then
	  	trace("BT-PAL - Bluetooth temporary ON")
		btcore.deleteAllDevices()
		btcore.setBluetoothOff()
	  else
	  	trace("BT-PAL - Bluetooth temporary OFF")
	  	tempBluetoothOn = false
	  end
  end
end

function events.profileSearchList(address, profiles)
	emit("profileSearchList", {address = address, profiles = profiles})
end

function events.serviceSearchList(address, services)
	emit("serviceSearchList", {address = address, services = services})
end

function events.pairingStatus(address, name, pairStatus)
	emit("bondingStatus", {address = address, name = name, bondStatus = pairStatus})
	if(pairStatus == "success") then
		btcore.setEyesFree(result, true)
	end
end

local function arbitrateAudio()
	local index = 0
	local preserveAudio = false
	
	trace("BT PAL - arbitrateAudio()")
	playDefaultRing = false
	
	-- Get call states
	index = table.getn(callInfo)
	for i = 1,index do
		if ( (callInfo[i].callState == "CALL_STATE_DIALING" or callInfo[i].callState == "CALL_STATE_ALERTING") and (localDialing == false) and (handsFreeMode == true)) then
			localDialing = true
			trace("BT PAL - localDialing:",localDialing)
		end
        if callInfo[i].callState == "CALL_STATE_RINGING" and callInfo[i].inband == false and localCurrentRingtoneSetting ~= 3 and localCurrentMasterRingtoneSetting == 1 then
			--Incoming call with no inband ringtone.(play default ring)
			trace("BT PAL - playDefaultRing")
			methods.currentRingtoneSetting()
			if (ringToneDone == false) then
				playDefaultRing = true
			else
				preserveAudio = true
			end
		elseif callInfo[i].callState == "CALL_STATE_ACTIVE" and (localCurrentRingtoneSetting == 3 or localCurrentMasterRingtoneSetting == 2) then
			ringtoneHandler = true
			trace("BT PAL - ringtoneHandler:",ringtoneHandler)
		elseif callInfo[i].callState == "CALL_STATE_RINGING" and callInfo[i].inband == true and localCurrentRingtoneSetting ~= 3 and localCurrentMasterRingtoneSetting == 1 then
			trace("BT PAL - playDefaultRing")
         	if (ringToneDone == false) then
            	playDefaultRing = true
			else
            	preserveAudio = true
			end
		end
	end
	
	if (playDefaultRing == true) then 
		-- We have to play default system ringtone.
		trace("BT PAL --- [Request Audio] - Play Default RingTone.")
		-- invoke mode manager API
		index = table.getn(callInfo)
		for i = 1,index do
			if callInfo[i].inband == true and localCurrentRingtoneSetting == 2 and localCurrentMasterRingtoneSetting == 1 then
				service.invoke(audioManager,"addInterruptSrc",{source="ringtone", exclusive="true", type="phone"})
			else
				service.invoke(audioManager,"addInterruptSrc",{source="ringtone", exclusive="true"})
			end
		end
		playDefaultRingID = 1
		ringToneDone = true
	else
		trace("BT PAL--NO NEED TO PLAY RINGTONE")
	end   
	
	--PreCond for Audio Request:-
	-- We have SCO(handsFreeMode==True) or there is a incoming call w/o inband ring support AND
	-- Audio is not already requested.
	trace("BT-PAL handsFreeMode:=",handsFreeMode)
	--removed or (vrActiveMode == true)
	if ((ringtoneHandler == true) or (localCurrentRingtoneSetting ~= 3 and localCurrentMasterRingtoneSetting == 1) or (localDialing == true)) then
		if ((handsFreeMode == true) or (localDialing == true)) then
			if audioRequestStatus == "NOT_REQUESTED" then
				-- Check if audio needs to be requested.
				trace("BT PAL - handsfreeMode or request status = ", audioRequestStatus)
				if ((handsFreeMode == true) or (localDialing == true)) then
					audioInfoSource = "phone"
				else
					--audioInfoSource = "phone_vr"
					audioInfoSource = "speech"
				end
				local index = table.getn(callInfo)
				for i = 1,index do
					if ( (callInfo[i].callState == "CALL_STATE_ACTIVE" or localCurrentRingtoneSetting == 3 or localCurrentMasterRingtoneSetting == 2 or localDialing == true) and hfmSourceStatus == false) then
						--Request for audio
						trace("BT PAL --- [Request Audio] - Requesting Audio")
						local result = service.invoke(audioManager,"addInterruptSrc",{source="hfm", exclusive="true"})
						trace("BT PAL --- [audioManager] - add interrupt source")
						audioRequestStatus = "REQUESTED"
						if (result and (result.action == "added") and (result.source == "hfm")) then
							trace("BT PAL --- [Request Audio] - Granted.")
							audioRequestStatus = "GRANTED"
							--service.invoke(audioManager,"setDeviceState", {device="MIC",user="all",state="ON"})
							micRequestSent = "REQUESTED"
							methods.getMicrophone()
							hfmSourceStatus = true
						else
							trace("BT PAL --- [Request Audio] - Denied.")
							audioRequestStatus = "NOT_REQUESTED"
							micRequestStatus   = "NOT_REQUESTED"
						end
					end
				end
			else
				--If audio is already requested or Granted then do nothing.
			end
			
			--If audio request is granted then go ahead and play default ringtone or start psse
			if audioRequestStatus == "GRANTED" and micRequestSent == "GRANTED" then
				--removed or (vrActiveMode == true)
				if (handsFreeMode == true) or (localDialing == true) then
					trace("BT PAL --- [Request Audio 1] - Start Psse.")
					--if default rightone is playing then end it and start call audio processing
					if (playDefaultRingID ~= 0) then
						--stop rigntone playback
						service.invoke(audioManager,"removeInterruptSrc",{source="ringtone"})
						playDefaultRingID = 0
					end
					-- when siri is active phonecall scenario happens.
					-- if (((handsFreeMode == true) or (localDialing == true)) and (audioInfoSource == "phone_vr")) then
					if (((handsFreeMode == true) or (localDialing == true)) and (audioInfoSource == "speech")) then
						audioInfoSource = "phone"
						trace("BT-PAL Call requestInformationSource--- It should be looked upon")
						local result = service.invoke(audioManager,"addInterruptSrc",{source="speech", exclusive="true"})
						audioRequestStatus = "REQUESTED"
						if (result and (result.action == "added") and (result.source == "speech")) then
							audioRequestStatus = "GRANTED"
							--audioInfoSource = "phone_vr"
							audioInfoSource = "speech"
							local result = service.invoke(audioManager,"removeInterruptSrc",{source="speech"})
							if (result and (result.action == "removed") and (result.source == "speech")) then
								audioInfoSource = "phone"
								trace("BT-PAL To avoid continuous calling of releaseinfosource for speech")
							else
								trace("BT-PAL Failed to release SPEECH source")
							end
						else
							trace("BT PAL --- [Request Audio] - Denied.")
							audioRequestStatus = "NOT_REQUESTED"
						end
					end	
				end
			end
		end
		--PreCond for Audio Release:-
		-- We no longer have SCO(handsFreeMode==False) AND we are no longer required to play default Ring
		-- removed and (vrActiveMode == false) 
	end
	if (handsFreeMode == false) and (localDialing == false) and (playDefaultRing == false) then
	    trace("BT PAL --- [Release Audio]")
		ringToneDone = false
		ringtoneHandler = false
		if audioRequestStatus == "REQUESTED" or audioRequestStatus == "GRANTED" or audioRequestStatus == "SUSPENDED" then
			-- release Audio.
			trace("BT PAL --- [Release Audio] - Releasing Audio.")
			if (playDefaultRingID ~= 0) then
				--stop rigntone playback
				service.invoke(audioManager,"removeInterruptSrc",{source="ringtone"})
				playDefaultRingID = 0
			end
			
			local result = service.invoke(audioManager,"removeInterruptSrc",{source="hfm"})
			hfmSourceStatus = false
			audioRequestStatus = "NOT_REQUESTED"
			methods.releaseMicrophone()
			trace("BT PAL --- [Release Audio] - Released.")
			--If call gets rejected directly from phone side.  
		else
		   trace("BT PAL --- [Release Audio] - audioRequestStatus: ",audioRequestStatus)
		end
	end    
	if (handsFreeMode == false) and (localDialing == true) and (audioStatus == false) then
	    trace("BT PAL --- [Release Audio]")
		if audioRequestStatus == "REQUESTED" or audioRequestStatus == "GRANTED" or audioRequestStatus == "SUSPENDED" then
			-- release Audio.	
			local result = service.invoke(audioManager,"removeInterruptSrc",{source="hfm"})
			hfmSourceStatus = false
			audioRequestStatus = "NOT_REQUESTED"
			methods.releaseMicrophone()
			trace("BT PAL --- [Release Audio] - Released.")
			--If call gets transferred to phone side.  
		else
		   trace("BT PAL --- [Release Audio] - audioRequestStatus: ",audioRequestStatus)
		end    
	else 
		trace("BT PAL --- handsfree: ", handsFreeMode)
		trace("BT PAL --- localDialing: ", localDialing)
		trace("BT PAL --- playDefaultRing: ", playDefaultRing)
	end
	
		--Stop ring if playing
	if (playDefaultRingID ~= 0) and (playDefaultRing == false) and (callInfo[1].callState == "CALL_STATE_ACTIVE") then
		trace("BT PAL --- STOP RINGTONE")
		service.invoke(audioManager,"removeInterruptSrc",{source="ringtone"})
		playDefaultRingID = 0
	end
end

function cleanPhoneNumber(number)
	local returnString = ""
	for i = 1, #number do
		local char = string.sub(number, i, i)
		if tonumber(char) then
			returnString = returnString..char
		end
	end
	return returnString
end

function sameNumber(number1, number2, useAsStrings)
	local firstNumber = cleanPhoneNumber(number1)
	local secondNumber = cleanPhoneNumber(number2)
	
	if (useAsStrings == true) then
		firstNumber = number1
		secondNumber = number2
	end
	
	if (firstNumber == nil and secondNumber ~= nil) or (firstNumber ~= nil and secondNumber == nil) then
		return false
	elseif (firstNumber == "" and secondNumber ~= "") or (firstNumber ~= "" and secondNumber == "") then
		return false
	elseif (string.find(firstNumber, secondNumber) ~= nil) or (string.find(secondNumber, firstNumber) ~= nil) then
		return true
	else
		return false
	end
end

function events.callState(callStateInfo, bdAddr)
	-- if the callid exits,then update the information
	heldCall = false;
	
	trace("BT-PAL -------------------------------------")
	trace("BT-PAL Current callstateInfo array status:")
	for tempVar =1, #callStateInfo do
		trace("BT-PAL Call id:",callStateInfo[tempVar].callId)
		trace("BT-PAL Call callState:",callStateInfo[tempVar].callState)
		trace("BT-PAL Call number:",callStateInfo[tempVar].number)
	end
	trace("BT-PAL -------------------------------------")
	
	for i = 1, #callStateInfo do
		local callState = callStateInfo[i].callState
		
		if callState == CALL_STATE_ONHOLD then
			heldCall = true
		end
		-- Check for SIRI support
		if callState ~= CALL_STATE_IDLE then
			callStateNotIdle = true 
			trace("BT-PAL set callstateNotIdle to TRUE")
		else 
			trace("BT-PAL set callstateNotIdle to FALSE")
			callStateNotIdle = false 
		end
		
		local id = findIndexForId(callStateInfo[i].callId)
		
		if (id ~= 0) and (callInfo[id] ~= nil) then
			-- Call still active, update information.
			callInfo[id].callState = callStateInfo[i].callState
			callInfo[id].number = callStateInfo[i].number
			callInfo[id].inband = callStateInfo[i].inband
		else
			if (( callStateInfo[i].number ~= nil ) and
				(( callState ~= CALL_STATE_TERMINATED ) and
					( callState ~= CALL_STATE_IDLE ) and
				( callState ~= nil ))) then
				-- this is a new call
				newPhoneCall = {}
				newPhoneCall.callId = callStateInfo[i].callId
				newPhoneCall.callState = callStateInfo[i].callState
				newPhoneCall.number = callStateInfo[i].number
				newPhoneCall.inband = callStateInfo[i].inband
				newPhoneCall.callTime = os.time()
				table.insert(callInfo,newPhoneCall)
				id = findIndexForId(callStateInfo[i].callId)
				
				--check if it is a dialed call
				if dialedCallInfo ~= nil then
					if (sameNumber(dialedCallInfo.number, callInfo[id].number) or sameNumber(dialedCallInfo.number, callStateInfo[i].reqNumber, true)) then
						-- this call was a dialed call, use stored name and url if available
						if dialedCallInfo.name ~= nil or dialedCallInfo.name ~= "" then
							callInfo[id].name = dialedCallInfo.name
						end
						
						if dialedCallInfo.url ~= nil or dialedCallInfo.url ~= "" then
							callInfo[id].url = dialedCallInfo.url
						end
						
						dialedCallInfo = nil
						
					end
				end
				if callInfo[id].name == nil or callInfo[id].name == "" then
					getNameByNumber(callInfo[id].number, id, bdAddr)
				end
			end
		end
	end
	
	--*********************** RESUME ANY HELD CALL **********************************
	local anyCallTerminated = false
	local idx = table.getn(callInfo)
	for i = 1,idx do
		if callInfo[i].callState == "CALL_STATE_TERMINATED" then
			trace("BT PAL - CALL_STATE_TERMINATED" )
			anyCallTerminated = true
			localDialing = false
			trace("BT PAL - localDialing:",localDialing)
			if (playDefaultRingID ~= 0) then
					--stop rigntone playback
					trace("BT-PAL Call got rejected directly from phone side")
					service.invoke(audioManager,"removeInterruptSrc",{source="ringtone"})
					playDefaultRingID = 0
			end      
			break
		end
	end
	if ( anyCallTerminated == true ) then
		for i = 1,idx do
			if callInfo[i].callState == "CALL_STATE_ON_HOLD" then
				local response
				btcore.resumeHeldCall(response)
				break
			end
		end
	end
	--*******************************************************************************
	emit("callState", { callStateInfo = callInfo })
	for i = 1, #callStateInfo do
		local callState = callStateInfo[i].callState
		if callState == CALL_STATE_TERMINATED or callState == CALL_STATE_IDLE or callState == nil then
			local id = findIndexForId(callStateInfo[i].callId)
			if (id ~= 0) and (callInfo[id] ~= nil) then
				table.remove(callInfo,id) --Call has ended, clear information on this call for later use of this table.
			end  
		end
	end
	arbitrateAudio(); --Will take care of all the call state cond.
end

function findIndexForId(callId)
	local returnIndex = 0
	for i = 1, #callInfo do
		if callId == callInfo[i].callId then
			returnIndex = i
		end
	end
	return returnIndex
end

function printTable(t)
	for k,v in pairs(t) do
		trace('',k,v)
		if type(v) == 'table' then
			for k,v in pairs(v) do
				trace('','',k,v)
			end
		end
	end
end

function getNameByNumber(number, callId, bdAddr)
	
	local resp = service.invoke(databaseServiceName, "getNameByPhoneNum", {database = "pb", 
	phoneNumber = number})
	
	if resp.result ~= nil then
		if resp.result[1] ~= nil then
			callInfo[callId].name = resp.result[1].formattedName
			--callInfo[callId].url = resp.result[1].url
		end
	end
	
end

function events.deviceUnpaired(address, name)
	emit("deviceUnbonded", {address = address, name = name})
end

function events.deviceSearchList(deviceSearchList)
	emit("deviceSearchList", {deviceSearchList = deviceSearchList})
end

function events.handsFreeMode(hfMode)
	emit("handsFreeMode", {hfMode = hfMode})
	trace("BT-PAL events.handsFreeMode")
	handsFreeMode = hfMode
	arbitrateAudio()
end

function events.incomingCallInfo(number, callId, inband)
	if (inband == nil) then
		emit("incomingCallInfo", {number = number, callId = callId, inband = false})
	else
		emit("incomingCallInfo", {number = number, callId = callId, inband = inband})
	end
end

function events.bluetoothAddress(address)
	emit("bluetoothAddress", {address = address})
end

function events.networkOperator(code, longName, shortName, mode, accTech, bdAddr)
	emit("networkOperator", {operatorCode = code, operatorLongName = longName,
	operatorShortName = shortName, operatorMode = mode, operatorAccTech = accTech})
end

function events.networkOperatorChanged(code, longName, shortName, mode, accTech, bdAddr)
	emit("networkOperatorChanged", {operatorCode = code, operatorLongName = longName,
	operatorShortName = shortName, operatorMode = mode, operatorAccTech = accTech})
end

function events.networkRegistrationState(state, bdAddr)
	emit("networkRegistrationState", {state = state})
end

function events.passkey(pin)
	emit("passkey", {pin = pin})
end

function events.securePairingRequest(address, name, pin)
	emit("secureBondingRequest", {address = address, name = name, pin = pin})
end

function events.serviceConnected(address, name, service, userConnected)
	trace("ServiceConnected: ",service );
	trace("Name: ",name );
	trace("userConnected: ",userConnected );
	-- To avoid the issue where both SPP and SPP_IAP were getting connecting, ignore purposeful disconnection of SPP/SPP_IAP connection
	-- when the disconnection is initiated by us and not by user
	-- Check if the connection was for SPP/SPP_IAP
	if( (service == SPP_PANDORA) or (service == SPP_IAP) ) then
		-- check if an SPP connection exists already
		if (isSPPConnected == false) then
			trace("An SPP connection established");
			isSPPConnected = true
			if( address == A2DPDeviceAddr ) then
				trace("Emitting SPP connection established");
				emit("serviceConnected", {address = address, name = name, service = service})
			end
			connectedSPPDeviceAddr = address
			connectedSPPServiceName = service
		else
			-- SPP connection exists already, so disconnect the new connection
			trace("An SPP connection already established");
			local response
			if( connectedSPPDeviceAddr == A2DPDeviceAddr ) then 
				btcore.startServiceDisconnection(response, address, service)	
				ignoreSPPSignalDeviceAddr = address
				ignoreSPPSignalServiceName = service
			else
				btcore.startServiceDisconnection(response, connectedSPPDeviceAddr, connectedSPPServiceName)	
				emit("serviceConnected", {address = address, name = name, service = service})
				connectedSPPDeviceAddr = address
				connectedSPPServiceName = service
			end
		end	
	else
		emit("serviceConnected", {address = address, name = name, service = service})
	end
	
	-- check if the service connected is A2DP and store the details for reference
	if( service == A2DP_SOURCE ) then
       	-- Check if the request was raised by us
		if ( true == isA2DPConnectionPending) then
			trace("BT-PAL - A2DP connection completed, check for pending SPP requests")
			isA2DPConnectionPending = false
			-- Check if the A2DP requests had blocked SPP requests
			checkPendingSPPConnection()		
		elseif( true == sendSPPRequestAtBonding) then 
		    local response
			btcore.startServiceConnection(response, address, SPP_PANDORA);
			btcore.startServiceConnection(response, address, SPP_IAP);
		end
	    sendSPPRequestAtBonding = false;
		
		-- Store the currently connected device details for reference
		isA2DPConnected = true
		A2DPDeviceAddr = address	
		
		-- Recovery mechanism as pandora service goes into error state if SPP profile connects before A2DP
		if ((isSPPConnected == true) and (A2DPDeviceAddr == connectedSPPDeviceAddr) ) then
		    trace("BT-PAL - A2DP connection completed,SPP already connected! Reconnecting for recovery....")
			local response
            -- Store the current settings for initiating reconnection
			if(connectedSPPServiceName == SPP_IAP) then 
				pendIAPRequestToBeSent = true;
				pendIAPDeviceAddr = connectedSPPDeviceAddr;
			else
			   pendSPPRequestToBeSent = true;
			   pendSPPDeviceAddr = connectedSPPDeviceAddr;
			end
            -- Disconnect the connected SPP
			btcore.startServiceDisconnection(response, connectedSPPDeviceAddr, connectedSPPServiceName);
		end
	end
end

function events.serviceConnectError(address, name, service)
	emit("serviceConnectError", {address = address, name = name, service = service})
	-- Check if A2DP connection failed
	if( service == A2DP_SOURCE ) then
		-- Check if the request was raised by us
		if ( true == isA2DPConnectionPending) then
			trace("BT-PAL - A2DP connection error, check for pending SPP requests")
			isA2DPConnectionPending = false
			-- Check if the A2DP requests had blocked SPP requests
			checkPendingSPPConnection()	
		end
		
		-- Reset the stored A2DP device details
		if(true == isA2DPConnected) and (address == A2DPDeviceAddr) then
			isA2DPConnected = false
			A2DPDeviceAddr = " "
		end
	end
end

function events.serviceConnectionRequest(address, name, service)
	emit("serviceConnectionRequest", {address = address, name = name, service = service})
end

function events.serviceDisconnected(address, name, service, reason)
	trace("ServiceDisConnected: ",service );
	trace("Name: ",name );
    -- To avoid the issue where both SPP and SPP_IAP were getting connecting, ignore purposeful disconnection of SPP/SPP_IAP connection
	-- when the disconnection is initiated by us and not by user
	-- Check if the disconnection was for SPP/SPP_IAP
	if( (service == SPP_PANDORA) or (service == SPP_IAP) ) then
		-- Check if SPP was previously connected
		if (isSPPConnected == true) then
			trace("An SPP connection already established 2");
			-- check if the current device disconnection was initiated by us
			if ((ignoreSPPSignalDeviceAddr == address) and (ignoreSPPSignalServiceName == service)) then
				trace("Ignoring disconnection");
				ignoreSPPSignalDeviceAddr = " "
				ignoreSPPSignalServiceName = " "
			else
				isSPPConnected = false	
				emit("serviceDisconnected", {address = address, name = name, service = service, reason = reason})
			end
		end
	else
		emit("serviceDisconnected", {address = address, name = name, service = service, reason = reason})
	end	
	
	-- Check if the currently connected A2DP device was disconnected
	if( (service == A2DP_SOURCE ) and (true == isA2DPConnected) and (address == A2DPDeviceAddr) )then
		-- reset the flags
		isA2DPConnected = false
		A2DPDeviceAddr = " "
	end
	
	checkPendingSPPConnection();
end

function events.signalQuality(rssi, bdAddr)
	emit("signalQuality", {rssi = rssi})
end

function events.standardPairingRequest(address, name, numPairedDevices)
	emit("standardBondingRequest", {address = address, name = name, numBondedDevices = numPairedDevices})
end

function events.callListUpdate(params)
	emit("callListUpdate", params)
end

function events.supportedFeaturesList(features, bdAddr)
	emit("supportedFeaturesList", {features = features, bdAddr = bdAddr})
end

function events.deviceDisconnected(address, name, reason)
	emit("deviceDisconnected", {address = address, name = name, reason = reason})
end

-- persistency interface

local function readPersistence(key)
	local val = 0
	local request = {}
	request.key = key;
	local persistentData, errStr = service.invoke(framService,"read", request)
	if ((persistentData ~= nil) and (errStr == nil)) then
		if(key == "BtAutoConnectList") then
			val = decode(persistentData.res)
		elseif (key == "BtPairedDeviceList") then
			val = decode(persistentData.res)
		else
			val = persistentData.res
		end
	else
		--trace("Error Reading Persistent data.  Error is: " ..errStr)
	end
	return val
end

local function writePersistence(key,value)
	local val
	if ( key == "BtAutoConnectList" ) then
		val = encode(value)
		local result = service.invoke(framService,"write", {[key] = val})
	elseif ( key == "BtPairedDeviceList" ) then
		val = encode(value)
		local result = service.invoke(framService,"write", {[key] = val})
	elseif ( key == "BtStatus" ) then
		val = value
		local result = service.invoke(framService,"write", {[key] = val})
	elseif ( key == "autoConnectionStatus" ) then
		val = value
		local result = service.invoke(framService,"write", {[key] = val})
	elseif ( key == "BtLocalDeviceName" ) then
		val = value
		local result = service.invoke(framService,"write", {[key] = val})
		key = "BtNameUpdateFlag"
		val = "1"
		local result = service.invoke(framService,"write", {[key] = val})
	else
		val = value
		local result = service.invoke(framService,"write", {[key] = val})
	end
end
-----------------------------------------------------------------------

local function handlePowerMode( nextPowerMode )
	trace( "currentPowerMode = ", currentPowerMode )
	trace( "nextPowerMode = ", nextPowerMode )
	local lastPowerMode = currentPowerMode
	currentPowerMode = nextPowerMode
	if (( currentPowerMode == 0 ) or
	    ( currentPowerMode == 1 ) or
		( currentPowerMode == 2 ) or
		( currentPowerMode == 4 ) ) then
		btcore.setIgnitionState(false)
		ignitionFalseValue = false
		if (handsFreeMode == true) then
			handsFreeMode = false;
			arbitrateAudio()
		end
	elseif (currentPowerMode == 3) then
		local status = readPersistence( "BtStatus" )
		trace("BT-PAL Persistence read status:",status)
		if((status == true) or (status == nil)) then
			btcore.setIgnitionState(true)
			localAutoConnectionStatus = readPersistence("autoConnectionStatus")
			if ( localAutoConnectionStatus == true ) then
				local response
				trace ("BT-PAL AutoConnect is now enabled")
				btcore.startAutoConnect(response, true)
				--timerHandlerAutoConnection:start(retryTime_AutoConnection)
				--trace ("BT-PAL RetryTimer Started from autoConnectionStatus!!")
			else
				trace ("BT-PAL AutoConnect is now disabled")
			end
		else
			ignitionFalseValue = true
		end
	end   
end

local function signalHandler( signalName, data )
	trace( "signalHandler" )
	if ( signalName == "powerMode" ) then
		trace( "Signal Name = ", signalName )
		if (( data ~= nil ) and
			( data.value ~= nil )) then
			handlePowerMode( data.value )
		end
	end
end

local function start()
	bluetoothService = assert(service.register(bluetoothServiceName, methods))
	btcore.registerEventCallBack(processEvent)
	btcore.registerFramCallBack(readPersistence,writePersistence)
	btcore.startup(config_filepath)
	
	service.subscribe( OnOffService, "powerMode", signalHandler )
	service.invoke( OnOffService, "getPowerMode", {} )
end


function methods.getMicrophone(params,context)
    trace("BT PAL --- Into getMicrophone()")
    -- when this method is called reset the flag to allow for a new mic request
    micRequestSent = "GRANTED"
    if not isMicAvaliable then
		isMicAvaliable = true
		--arbitrateAudio()
		local giveMode = "open"
		emit("micState", {mode=giveMode})
	end
    -- when this method is called reset the flag to allow for a new mic request
    micRequestStatus = "NOT_REQUESTED"
    trace("BT PAL --- Out of getMicrophone()")
    return{}
end

function methods.releaseMicrophone(params,context)
    trace("BT PAL --- Into releaseMicrophone()")
    -- when this method is called reset the flag to allow for a new mic request
    micRequestStatus = "NOT_REQUESTED"
    if isMicAvaliable then
		isMicAvaliable = false
		--arbitrateAudio()
		local takeMode = "released"
		emit("micState", {mode=takeMode})
	end
    if not isMicAvaliable then
		--audio mode is not handsfree any more; de register from microphone manager stack
		--service.invoke(audioManager,"setDeviceState", {device="MIC",user="all",state="OFF"})
	end
    trace("BT PAL --- Out of releaseMicrophone()")
    return{}
end


-- dbus methods
function methods.getProperties(params,context,replyExpected)
	return btcore.getProperties(params.properties)
end

function methods.setPin(params,context,replyExpected)
	local response = standardResponse(context, replyExpected)
	if not btcore.setPin(response,params.pin) then
		if response then
			return dummyRes
		end
	end
end

function methods.setBluetoothStatus(params,context,replyExpected)
	local response = standardResponse(context, replyExpected)
	if params.enable == true then
		if ((ignitionFalseValue == true) and ((currentPowerMode == 1) or (currentPowerMode == 2) or (currentPowerMode == 7) or 
		(currentPowerMode == 5) or (currentPowerMode == 3) or (currentPowerMode == 4) or (currentPowerMode == 6))) then
			trace("BT-PAL Work around for power mode handling")
			btcore.setIgnitionState(true)
			ignitionFalseValue = false
		end
		if tempBluetoothOn then
			tempBluetoothOn = false
		end
		if not btcore.setBluetoothOn(response) then
			if response then
				return dummyRes
			end
		end
	else
		if not btcore.setBluetoothOff(response) then
			if response then
				return dummyRes
			end
		end
	end
end

-- The API startDeviceBonding() should not be called to start a pairing request. Instead the API startServiceConnect() should be used for pairing also.
function methods.startDeviceBonding(params,context,replyExpected)
	local response = standardResponse(context, replyExpected)
	if not btcore.enterBondingMode(response, params.timeout) then
		if response then
			return dummyRes
		end
	end
end

function methods.deleteDevice(params,context,replyExpected)
	local response = standardResponse(context, replyExpected)
	if not btcore.deleteDevice(response, params.address) then
		if response then
			return dummyRes
		end
	end
end

function methods.deleteAllDevices(params,context,replyExpected)
   if bluetoothStatus then
		local response = standardResponse(context, replyExpected)
		if not btcore.deleteAllDevices(response) then
			if response then
				return dummyRes
			end
		end
   else
		trace("BT-PAL - Bluetooth OFF, unable to process delete request. Turning ON BT")
		btcore.setBluetoothOn()
		tempBluetoothOn = true
  end
end

function methods.enterBondingMode(params,context,replyExpected)
	local response = standardResponse(context, replyExpected)
	if not btcore.enterBondingMode(response,DEV_DISCOVERABLE_ON_TIMEOUT) then
		if response then
		    return dummyRes
		end
	end
end

function methods.exitBondingMode(params,context,replyExpected)
	local response = standardResponse(context, replyExpected)
	if not btcore.exitBondingMode(response,DEV_DISCOVERABLE_ON_TIMEOUT) then
		if response then
		    return dummyRes
		end
	end
end

function methods.startDeviceSearch(params,context,replyExpected)
	local response = standardResponse(context, replyExpected)
	if not btcore.startDeviceSearch(response, params.maxDevices, params.timeout) then
		if response then
			return dummyRes
		end
	end
end

function methods.stopDeviceSearch(params,context,replyExpected)
	local response = standardResponse(context, replyExpected)
	if not btcore.stopDeviceSearch(response) then
		if response then
			return dummyRes
		end
	end
	local response2
	btcore.exitBondingMode(response2,DEV_DISCOVERABLE_ON_TIMEOUT) 
end

function methods.standardBondingReply(params,context,replyExpected)
	local response = standardResponse(context, replyExpected)
	if not btcore.standardBondingReply(response, params.address, params.accept, params.trusted) then
		if response then
			return dummyRes
		end
	end
end

function methods.secureBondingReply(params,context,replyExpected)
	local response = standardResponse(context, replyExpected)
	if(params.accept == true) then
		sendSPPRequestAtBonding = true;
	end
	if not btcore.secureSimpleBondingReply(response, params.address, params.accept, params.trusted) then
		if response then
			return dummyRes
		end
	end
end

function methods.startServiceConnect(params,context,replyExpected)
	local response = standardResponse(context, replyExpected)
	local sendRequest = true
	-- Check if the connection request is for A2DP
	if (params.service == A2DP_SOURCE) then
		-- If request is being reraised for the same device, ignore request else set the flag
		if not (isA2DPConnected and (A2DPDeviceAddr == params.address)) then
			isA2DPConnectionPending = true
			trace("BT-PAL - A2DP connection initiated, pend SPP requests if any")
		end
	-- Check if the connection request is for SPP when response for A2DP is still pending
	elseif ( ((params.service == SPP_PANDORA) or (params.service == SPP_IAP)) and isA2DPConnectionPending) then
		-- Store the SPP_PANDORA request details to be sent later
		if (params.service == SPP_PANDORA) then
			trace("BT-PAL - A2DP connection initiated, pend SPP_PANDORA request")	
			pendSPPRequestToBeSent = true
			pendSPPDeviceAddr = params.address
		-- Store the SPP_IAP_Iphone request details to be sent later
		else 
			trace("BT-PAL - A2DP connection initiated, pend SPP_IAP_Iphone request")	
			pendIAPRequestToBeSent = true
			pendIAPDeviceAddr = params.address
		end			
		sendRequest = false
	end
	-- Check if the raised request is to be processed immediately or kept pending
	if (sendRequest) then 
		if not btcore.startServiceConnection(response, params.address, params.service, params.instance) then
			if response then
				return dummyRes
			end
		end
	end
end

function methods.startServiceDisconnect(params,context,replyExpected)
	local response = standardResponse(context, replyExpected)
	if not btcore.startServiceDisconnection(response, params.address, params.service, params.internal) then
		if response then
			return dummyRes
		end
	end
end

function methods.serviceConnectReply(params,context,replyExpected)
	local response = standardResponse(context, replyExpected)
	if not btcore.serviceConnectionReply(response, params.address, params.service,params.accept) then
		if response then
			return dummyRes
		end
	end
end

function methods.renameRemoteDevice(params,context,replyExpected)
	local response = standardResponse(context, replyExpected)
	if not btcore.renameBondedDevice(response, params.address,params.name) then
		if response then
			return dummyRes
		end
	end
end

function methods.renameHeadUnit(params,context,replyExpected)
	local response = standardResponse(context, replyExpected)
	if not btcore.renameLocalDevice(response, params.name) then
		if response then
			return dummyRes
		end
	end
end

function methods.dial(params,context,replyExpected)
	local response
	if replyExpected then
		function response(code, description, reason, callId)
			service.returnResult(context, {code = code, description = description, reason = reason, callId = callId})
		end
	else
		service.freeReqContext(context)
	end
	--store params
	dialedCallInfo = {}
	dialedCallInfo.number = params.number
	
	if (params.name ~= "") and (params.name ~= nil) then
		dialedCallInfo.name = params.name
	else
		dialedCallInfo.name = nil
	end   
	
	if (params.url ~= "") and (params.url ~= nil) then
		dialedCallInfo.url = params.url
	else
		dialedCallInfo.url = nil
	end
	
	if not btcore.dial(response, params.number) then
		if response then
			return dummyRes
		end
	end
end

function methods.reDial(params,context,replyExpected)
	local response
	if replyExpected then
		trace ("BT-PAL Redial-- Reply expected!!")
		function response(code, description, reason, callId)
			trace ("BT-PAL Redial-- Sending reply!!")
			service.returnResult(context, {code = code, description = description, reason = reason, callId = callId})
		end
	else
		service.freeReqContext(context)
	end
	if not btcore.reDial(response) then
		if response then
			return dummyRes
		end
	end
end

function methods.sendDtmfTone(params,context,replyExpected)
	local response = standardResponse(context, replyExpected)
	if not btcore.sendDtmfTone(response,params.dtmfTone) then
		if response then
			return dummyRes
		end
	end
end

function methods.acceptIncomingCall(params,context,replyExpected)
	local response = standardResponseWithReason( context,replyExpected )
	if not btcore.acceptIncomingCall(response) then
		if response then
			return dummyRes
		end
	else 
		ringToneDone = true;
	end
end

function methods.endCall(params,context,replyExpected)
	local response = standardResponseWithReason( context,replyExpected )
	if not btcore.endCall(response, params.callId) then
		if response then
			return dummyRes
		end
	end
end

function methods.endActiveCall(params,context,replyExpected)
	local response = standardResponseWithReason( context,replyExpected )
	if not btcore.endActiveCall(response) then
		if response then
			return dummyRes
		end
	end
end

function methods.endAllCalls(params,context,replyExpected)
	local response = standardResponseWithReason( context,replyExpected )
	if not btcore.endAllCalls(response) then
		if response then
			return dummyRes
		end
	end
end

function methods.rejectIncomingCall(params,context,replyExpected)
	local response = standardResponseWithReason( context,replyExpected )
	if not btcore.rejectIncomingCall(response) then
		if response then
			return dummyRes
		end
	else 
		--ringToneDone = true;
		if(playDefaultRingID ~= 0) then
			service.invoke(audioManager,"removeInterruptSrc",{source="ringtone"})
			playDefaultRingID = 0
		end
	end
end

function methods.holdActiveCall(params,context,replyExpected)
	local response = standardResponseWithReason( context,replyExpected )
	if heldCall == true then
		if not btcore.resumeHeldCall(response) then
			if response then
				return dummyRes
			end
		end
	else
		if not btcore.holdActiveCall(response) then
			if response then
				return dummyRes
			end
		end
	end
end

function methods.activateHeldCall(params,context,replyExpected)
	local response = standardResponseWithReason( context,replyExpected )
	if not btcore.resumeHeldCall(response) then
		if response then
			return dummyRes
		end
	end
end

function methods.conferenceCall(params,context,replyExpected)
	local response = standardResponseWithReason( context,replyExpected )
	if not btcore.conferenceCall(response) then
		if response then
			return dummyRes
		end
	end
end

function methods.setHfMode(params,context,replyExpected)
	local response = standardResponse(context, replyExpected)
	if not btcore.setHfMode(response,params.hfMode) then
		if response then
			return dummyRes
		end
	end
end

function methods.swapCalls(params,context,replyExpected)
	local response = standardResponse(context, replyExpected)
	if not btcore.swapCalls(response) then
		if response then
			return dummyRes
		end
	end
end

function methods.getNetworkOperatorInfo(params,context,replyExpected)
	local response
	if replyExpected then
		function response(code, description,operatorCode,operatorLongName,operatorShortName,operatorMode,operatorAccTech)
			service.returnResult(context, {code = code
				, description = description
				, operatorCode = operatorCode
				, operatorLongName = operatorLongName
				, operatorShortName = operatorShortName
				, operatorMode = operatorMode
				, operatorAccTech = operatorAccTech
			})
		end
	else
		service.freeReqContext(context)
	end
	if not btcore.getNetworkOperatorInfo(response) then
		if response then
			return dummyRes
		end
	end
end

function methods.getRadioStatus(params,context,replyExpected)
	local response
	if replyExpected then
		function response(code, description,btAddressList,connRoleList,linkQualityList,rssiList,txPowerList,linkModeList)
			service.returnResult(context, {code = code
				, description = description
				, btAddressList = btAddressList
				, connRoleList = connRoleList
				, linkQualityList = linkQualityList
				, rssiList = rssiList
				, txPowerList = txPowerList
				, linkModeList = linkModeList
			})
		end
	else
		service.freeReqContext(context)
	end
	if not btcore.getRadioStatus(response) then
		if response then
			return dummyRes
		end
	end
end

local function disableAutoConnection()
	--[[ timerHandlerAutoConnection:stop()
	trace ("BT-PAL Retry Timer expired: Now disableAutoConnection if enabled")
	if ( localAutoConnectionStatus == true ) then
		btcore.stopAutoConnect()
		trace ("BT-PAL stopAutoConnect Called!!")
	end
	]]--
end

function methods.enableAutoConnection(params,context,replyExpected)
	trace ("BT-PAL Inside enableAutoConnection with value ",params.enable)
	if (localAutoConnectionStatus ~= params.enable) then
		writePersistence("autoConnectionStatus",params.enable)
		localAutoConnectionStatus = params.enable
		if ( localAutoConnectionStatus == true ) then
		    local response 
			btcore.startAutoConnect(response, true)
			--timerHandlerAutoConnection:start(retryTime_AutoConnection)
			trace ("BT-PAL RetryTimer Started from enableAutoConnection!!")
		end
	end
	service.returnResult(context, {code = 0, description = "success"})
end

function methods.autoConnectionStatus(params,context,replyExpected)
	trace ("BT-PAL Inside autoConnectionStatus ")
	localAutoConnectionStatus = readPersistence("autoConnectionStatus")
	--if ( localAutoConnectionStatus == true ) then
		--trace ("BT-PAL AutoConnect is now enabled")
		--btcore.startAutoConnect()
		--timerHandlerAutoConnection:start(retryTime_AutoConnection)
		--trace ("BT-PAL RetryTimer Started from autoConnectionStatus!!")
	--end
	service.returnResult(context, {code = 0, description = "success", enable = localAutoConnectionStatus})
end 

function methods.selectRingtone(params,context,replyExpected)
	trace ("BT-PAL Inside selectRingtone with value ",params.toneId)
	if ( (localCurrentRingtoneSetting ~= params.toneId) and (currentPowerMode == 3) ) then
		writePersistence("currentRingtoneSetting",params.toneId)
		localCurrentRingtoneSetting = params.toneId
	end
	service.returnResult(context, {code = 0, description = "success"})
end

function methods.currentRingtoneSetting(params,context,replyExpected)
	trace ("BT-PAL Inside currentRingtoneSetting ")
	localCurrentRingtoneSetting = readPersistence("currentRingtoneSetting")
	emit("currentRingtoneSetting", {toneId = localCurrentRingtoneSetting})
	service.returnResult(context, {code = 0, description = "success", toneId = localCurrentRingtoneSetting})
end

function methods.selectMasterRingtone(params,context,replyExpected)
	trace ("BT-PAL Inside selectMasterRingtone with value ",params.toneId)
	if (localCurrentMasterRingtoneSetting ~= params.toneId) then
		writePersistence("currentMasterRingtoneSetting",params.toneId)
		localCurrentMasterRingtoneSetting = params.toneId
		--if ((localCurrentMasterRingtoneSetting == 2) and (currentRingtoneSetting ~= 3)) then
			--writePersistence("currentRingtoneSetting",3)
			--localCurrentRingtoneSetting = 3
		--end
	end
	service.returnResult(context, {code = 0, description = "success"})
end

function methods.currentMasterRingtoneSetting(params,context,replyExpected)
	trace ("BT-PAL Inside currentMasterRingtoneSetting ")
	localCurrentMasterRingtoneSetting = readPersistence("currentMasterRingtoneSetting")
	emit("currentMasterRingtoneSetting", {toneId = localCurrentMasterRingtoneSetting})
	service.returnResult(context, {code = 0, description = "success", toneId = localCurrentMasterRingtoneSetting})
end

function methods.getLinkQuality(params,context,replyExpected)
	local response
	local retLinkQualityVal
	local retCode
	local retDescription
	local retBtAddress
	
	sendLinkQuality = params.enable
	if ( sendLinkQuality == true ) then
		if ( timerStartedStatus == false ) then
			timerHandler:start(timerValue)
			timerStartedStatus = true
		end
	else
		if ( timerStartedStatus == true ) then
			timerHandler:stop()
			timerStartedStatus = false
		end
	end
	
	if replyExpected then
		function response(code, description,btAddressList,connRoleList,linkQualityList,rssiList,txPowerList,linkModeList)
			if (( btAddressList ~= nil ) and
			( btAddressList[1] ~= nil )) then
				retLinkQualityVal = btAddressList[1].rssi
				retCode           = code
				retDescription    = description
				retBtAddress      = btAddressList[1].address
				emit("linkQuality", {quality = retLinkQualityVal})
				service.returnResult(context, {code = retCode
					, description = retDescription
					, btAddress = retBtAddress
					, linkQuality = retLinkQualityVal
				})
			else
				service.returnResult(context, {code = 14
					, description = "BT No Connection"
				})
			end
		end
	else
		service.freeReqContext(context)
	end
	
	if not btcore.getRadioStatus(response) then
		if response then
			return dummyRes
		end
	end
end


local function checkLinkQuality()
	local response
	local retLinkQualityVal
	
	if ( sendLinkQuality == true ) then
		trace ( " <<---checkLinkQuality called --->>")
		timerHandler:stop()
		function response(code, description,btAddressList,connRoleList,linkQualityList,rssiList,txPowerList,linkModeList)
			if (( btAddressList ~= nil ) and
			( btAddressList[1] ~= nil )) then
				retLinkQualityVal = btAddressList[1].rssi
				linkQualityVal_New = retLinkQualityVal
				if (linkQualityVal_New ~= linkQualityVal_Old) then
				emit("linkQuality", {quality = linkQualityVal_New})
				end
				linkQualityVal_Old = linkQualityVal_New
			else
				service.freeReqContext(context)
			end
		end
		
		if not btcore.getRadioStatus(response) then
			if response then
				return dummyRes
			end
		end
		timerHandler:start(timerValue)
	end
end

function methods.getBondedDeviceList(params,context,replyExpected)
	local response
	if replyExpected then
		function response(code, description,pairedDeviceList)
			service.returnResult(context, {code = code
				, description = description
				, pairedDeviceList = pairedDeviceList
			})
		end
	else
		service.freeReqContext(context)
	end
	if not btcore.getBondedDeviceList(response) then
		if response then
			return dummyRes
		end
	end
end

function methods.getSupportedProfileList(params,context,replyExpected)
	local response
	if replyExpected then
		function response(code, description,serviceList)
			service.returnResult(context, {code = code
				, description = description
				, serviceList = serviceList
			})
		end
	else
		service.freeReqContext(context)
	end
	if not btcore.serviceListQuery(response,params.address) then
		if response then
			return dummyRes
		end
	end
end

function events.audioStatus(status, bdAddr)
	audioStatus = status
	trace("BT-PAL audiostatus:",status)
	if (audioStatus == true) then
		trace("BT-PAL ---------------SCO CONNECTED-----------")
	else
		trace("BT-PAL ---------------SCO DISCONNECTED-----------")
	end

	emit("audioStatus", {audioStatus = audioStatus})
end

--Audio management function's
-- Release Audio will end active call and stop PSSE
function methods.releaseAudio(params,context,replyExpected)
	local modeRes = {code = 0, description = "Success"}
	
	--Stop ring if playing
	if (playDefaultRingID ~= 0) then
		service.invoke(audioManager,"removeInterruptSrc",{source="ringtone"})
		playDefaultRingID = 0
	end
    --end call
	function response(code, description, reason)
	end
	
	-- Get call states
	local index = table.getn(callInfo)
	for i = 1,index do
        if callStatus[i].callState == "CALL_STATE_RINGING" then
            btcore.rejectIncomingCall(response)
			elseif callStatus[i].callState == "CALL_STATE_ACTIVE" or callStatus[i].callState == "CALL_STATE_DIALING" or callStatus[i].callState == "CALL_STATE_ALERTING" or callStatus[i].callState == "CALL_STATE_ONHOLD" then
            btcore.endActiveCall(response)
		end
	end
    trace("BT PAL --- releaseAudio() - Released Audio.")
	return modeRes
end

-- Resume audio will start psse if any call is active.
function methods.resumeAudio(params,context,replyExpected)
    local modeRes = {code = 0, description = "Success"}
	
    if audioRequestStatus == "SUSPENDED" then
        local psseStatus = service.invoke(psseControlServiceName,"getSHF_Scenario")
		--removed  or (vrActiveMode == true)
        if (psseStatus and ((handsFreeMode == true)) and (handsfree_Scenario ~=  psseStatus.scenario )) then
            service.invoke(psseControlServiceName,"setSHF_Scenario", {scenario = handsfree_Scenario, mode = "START"})
			elseif (playDefaultRing == true) and (playDefaultRingID == 0) then
			service.invoke(audioManager,"addInterruptSrc",{source="ringtone", exclusive="true"})
            playDefaultRingID = 1
		end
        audioRequestStatus = "GRANTED"
	end
    trace("BT PAL --- resumeAudio() - Resumed Audio.")
	return modeRes
end

-- Suspend audio will only stop psse and not end call. This is required for VR barge in.
function methods.suspendAudio(params,context,replyExpected)
    local modeRes = {code = 0, description = "Success"}
	
    if audioRequestStatus == "GRANTED" then
        --Stop Psse if running
        local psseStatus = service.invoke(psseControlServiceName,"getSHF_Scenario")
		if (psseStatus and (handsfree_Scenario ==  psseStatus.scenario )) then
            service.invoke(psseControlServiceName,"setSHF_Scenario", {scenario = handsfree_Scenario, mode = "STOP"})
		end
		
        --Stop ring if playing
        if (playDefaultRingID ~= 0) then
            service.invoke(audioManager,"addInterruptSrc",{source="ringtone", exclusive="true"})
			playDefaultRingID = 0
		end
        audioRequestStatus = "SUSPENDED"
	end
    trace("BT PAL --- suspendAudio() - suspended Audio.")
	return modeRes
end

-- Register for the AudioManager service to know if UISpeech has audio
function CurrentAudioSrc(signal, params)
	--if (params.action == "added" and params.allowed == true and params.source == "hfm") then
	if (params.action == "added" and params.source == "hfm") then
		--vrSessionActive = true
		trace("BT-PAL --- HFM added ")
		if (audioRequestStatus ~= "GRANTED") then
			trace("BT-PAL --- Audio not granted, do the needful")
			audioRequestStatus = "GRANTED"

			if (micRequestSent ~= "REQUESTED") then
				--service.invoke(audioManager,"setDeviceState", {device="MIC",user="all",state="ON"})
				micRequestSent = "REQUESTED"
				methods.getMicrophone()
			end
			hfmSourceStatus = true
			arbitrateAudio()
		end
	end	
end

-------------------------------------------------------------------------------
-- Called When the FRAM Service is Available
-------------------------------------------------------------------------------
local function onFramServiceAvailable(newName, oldOwner, newOwner)
	if framAvailableSubscription then
		service.unsubscribe(framAvailableSubscription)
		framAvailableSubscription = nil
	end
	
	start()
	
	   -- start trace
   traceClient.start("btservice")
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------
local function init()
	framAvailableSubscription = assert(service.subscribeOwnerChanged(framService, onFramServiceAvailable))
	if service.nameHasOwner(framService) then
		onFramServiceAvailable("x", "y", "z") -- need to change xyz if we check the args
	end
	
	-- Register with AudioManager Service to know if UISpeech has audio
	service.subscribe(audioManager,"interruptSrc",CurrentAudioSrc)
	methods.currentRingtoneSetting()
	--timerHandlerAutoConnection = timer.new(disableAutoConnection)
	--trace("BT-PAL -----STARTING TIME---------")	
	--methods.autoConnectionStatus()
	timerHandler = timer.new(checkLinkQuality)
end

init()
