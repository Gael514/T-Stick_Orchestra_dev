// this instrument requires the installations of SC3 plugins: https://supercollider.github.io/sc3-plugins/
(
{
	arg interface, port, out, mode;
	var instrument;
	instrument = Dictionary.new;

	////////////////////////////////
	//2. initialize global variables
	////////////////////////////////

	// declare a function for initializing variables
	instrument.add(\initVariables -> {

		// interface  name, receiving port, audio output bus, mono/stereo
		instrument.add(\interface ->  interface);
		instrument.add(\recvPort -> port);
		// default mode is stereo
		instrument.add(\audioChan -> (mode != "mono").if(2,1)); // NECESSARY???

		// Audio folder (folder must at the same level as the scd file)
		instrument.add(\audio -> "granulatorAudio");

		// project path
		instrument.add(\projectPath -> PathName.new(thisProcess.nowExecutingPath).parentPath);

		// List of DMI control parameters [OSC address, size, mapped or not]
		instrument.add(\tStickParam -> [
			["/raw/capsense"                 ,      30,         ],
			["/raw/fsr"                      ,       1, "mapped"],
			["/raw/accl"                     ,       3, "mapped"],
			["/raw/gyro"                     ,       3, "mapped"],
			["/raw/magn"                     ,       3,         ],
			["/instrument/shakexyz"          ,       3, "mapped"],
			["/instrument/squeeze"           ,       1,         ],
			["/instrument/touch/all"         ,       1, "mapped"],
			["/instrument/touch/top"         ,       1,         ],
			["/instrument/touch/middle"      ,       1,         ],
			["/instrument/touch/bottom"      ,       1,         ],
			["/instrument/touch/discrete"    ,      30, "mapped"],
			["/instrument/jabxyz"            ,       3,         ],
			["/instrument/brush"             ,       1,         ],
			["/instrument/multibrush"        ,       4,         ],
			["/instrument/rub"               ,       1,         ],
			["/instrument/multirub"          ,       4,         ],
			["/instrument/button/count"      ,       1,         ],
			["/instrument/button/tap"        ,       1,         ],
			["/instrument/button/ttap"       ,       1,         ],
			["/battery/percentage"           ,       1,         ],
			["/battery/current"              ,       1,         ],
			["/battery/timetoempty"          ,       1,         ],
			["/battery/voltage"              ,       1,         ],
			["/orientation"                  ,       4,         ],
			["/ypr"                          ,       3,         ]
		]);

		// List of sound synthesis control parameters [, [intial values], mapped or not]
		instrument.add(\synthParam -> [
			["param1"        ,                   [ 0 ],         ],
			["param2"        , [ 1, 1, 1, 1, 1, 1, 1 ], "mapped"],
			["param3"        ,                [ 0.33 ], "mapped"],
		]);

		// Turn on/off calibration
		instrument.add(\toggle -> 0);

		// Dictionnary containing calibration results
		instrument.add(\calibrationVals -> Dictionary.with(*[
			\fsr -> [0, 4095],
			\shakeThresh -> [0, 2],
			\shakeMax -> [0, 6]
		]));
		//
		instrument.add(\triBandF1 -> 500);
		instrument.add(\triBandF2 -> 8000);

		// Add variables specific to the instrument/piece
		instrument.add(\setRates -> [
			[1, 1, 1, 1, 1, 1, 1],
			[1, 1, 1, 1/2, 1/2, 2, 2],
			[1, 1, 3/2, 3/2, 1/2, 3/4, 2],
			[1, 1/2, 2, 3/2, 5/4, 3/4, 5/8],
		]);

		// Dictionary of SynthDef arguments
		instrument.add(\synthDefParam -> instrument[\synthParam].collect{
			arg item, i;
			var dic;
			if(item[2] == "mapped") {
				// create a Dictionary for each argument that is mapped
				dic = Dictionary();
				// argument name
				dic.add(\arg -> item[0]);
				// argument initial value(s)
				dic.add(\init -> item[1]);
			}
		});
		instrument[\synthDefParam] = instrument[\synthDefParam].reject({|item| item.isNil});
		(interface + ": Variables initalized").postln;
	});
	// end of \initVariables function

	////////////////////////////////
	//3. define piece-specific functions
	////////////////////////////////

	// declare a function for specific functions
	instrument.add(\specificFunctions -> {

		// function returns an array of objects assigned to a key in an array of Dictionaries
		instrument.add(\arrayKey -> {
			arg list, key;
			list.collect({
				arg item, i;
				item[key];
			});
		});

		// create speciific functions
		// Reads only first channel in case there are some stereo files
		instrument.add(\makeBuffers -> {
			instrument.add(
				\buffs -> PathName(instrument[\projectPath] ++ instrument[\audio]).entries.collect({
					arg item, index;
					Buffer.readChannel(s, item.fullPath, channels:0);
				})
			);
			"".postln;"--------------------------------".postln; (interface + ": Buffers created").postln;"--------------------------------".postln;
		});

		// Calibration Function
		instrument.add(\calibrationFunc -> {
			arg onOff=0, bus=0, dict=nil, key=nil;
			var arr=[], val, minVal=4095, maxVal=0;

			if(onOff == 1) {
				instrument.add(\calibRoutine -> Routine{
					loop{
						val = bus.getSynchronous;

						if( arr.size < 10,
							{
								arr = arr.add(val);
							},{
								arr = arr.add(val);
								arr = arr.shift(-1);
								arr = arr.keep(10);
							}
						);
						minVal = minVal.min(arr.mean);
						maxVal = maxVal.max(arr.mean);
						(key ++ " min value: " ++ minVal.round(0.001) ++ " - " ++ key ++ " max value: " ++ maxVal.round(0.001)).postln;

						dict[key] = [minVal, maxVal];
						0.01.wait;
					}
				});
				instrument[\calibRoutine].play;
			}{
				instrument[\calibRoutine].stop;
			};
		});

		// Create control busses when server has booted
		instrument.add(\makeBusses -> {
			var bus = 0;
			// Dictionary of busses, keys are DMI source names
			instrument.add(\busDmi -> Dictionary.new);
			// loop through all interface control signals
			instrument[\tStickParam].do({
				arg item;
				if(item[2] == "mapped") {
					// create control busses, number of channels from \tStickParam array
					instrument[\busDmi].add((interface ++ item[0]) -> Bus.control(s, item[1].asInteger));
					// update total number of busses created
					bus = bus + item[1].asInteger;
				};
			});

			(interface ++" interface control busses: " ++ bus.asString).postln;

			// Dictionary of busses, keys are Synth arguments names
			bus = 0;
			instrument.add(\busSynth -> Dictionary.new);
			instrument[\arrayKey].value(instrument[\synthDefParam], \arg).do({
				arg item, i;
				// bus number of channels is the size of the parameter initial value
				instrument[\busSynth].add(item -> Bus.control(s, instrument[\synthDefParam][i][\init].size));
				bus = bus + instrument[\synthDefParam][i][\init].size;
			});
			instrument[\busSynth].add(\fx -> Bus.audio(s,instrument[\audioChan]));
			instrument[\busSynth].add(\lim -> Bus.audio(s,instrument[\audioChan]));
			(interface  ++" Synth control busses: "++ bus.asString).postln;
		});

		// Cretate Synth mapping the interface control busses to sound parameters control busses
		instrument.add(\makeBusMappings -> {
			s.bind({
				instrument.add(\mappingGrp -> Group.new);
				{
					// mapping for Synth parameter bufPos (grain position in the buffer)
					var mapBufPos;
					mapBufPos = In.kr(instrument[\busDmi][instrument[\interface] ++ "/raw/accl"].subBus(0), 1);
					mapBufPos = mapBufPos.lincurve(-10, 10, 0, 1, 0, nil);
					Out.kr(instrument[\busSynth]["param1"], mapBufPos);
				}.play(instrument[\mappingGrp]);


				{
					// mapping for Synth parameter gainLow, gainMid, gainHigh
					var mapGainLow, mapGainMid, mapGainHigh, gyro;
					gyro = In.kr(instrument[\busDmi][instrument[\interface] ++ "/raw/gyro"], 3);
					mapGainLow = gyro[2].abs * 2;
					mapGainMid = gyro[0] * 8;
					mapGainHigh = gyro[1] * 6;
					Out.kr(instrument[\busSynth]["gainLow"],mapGainLow);
					Out.kr(instrument[\busSynth]["gainMid"], mapGainMid);
					Out.kr(instrument[\busSynth]["gainHigh"], mapGainHigh);
				}.play(instrument[\mappingGrp]);

			})
		});

		// Create audio Synth
		instrument.add(\makeNodes -> {
			s.bind({
				instrument.add(\mainGrp -> Group.new);
				instrument.add(\fxGrp -> Group.after(instrument[\mainGrp]));
				instrument.add(\limGrp -> Group.after(instrument[\fxGrp]));

				// 3 band Synth
				instrument.add(\triBandSynth -> Synth(\triBand, [
					\in, instrument[\busSynth][\fx],
					\freq1, instrument[\triBandF1],
					\freq2, instrument[\triBandF2],
					\gainLow, 1.0,
					\gainMid, 1.0,
					\gainHigh, 1.0,
				], instrument[\fxGrp]));

				// reverb Synth (tail of the fx group)
				instrument.add(\revSynth -> Synth.tail(instrument[\fxGrp], \reverb, [\in, instrument[\busSynth][\fx],
					\mix, 0.33,
					\room, 0.5,
					\damp, 0.2,
				], instrument[\fxGrp]));

				// limiter Synth
				instrument.add(\limitSynth -> Synth(\comp, [\in, instrument[\busSynth][\fx], \thesh, -3.dbamp, \out, out], instrument[\limGrp]));

				// start a Synth and map the arguments to the control busses
				instrument.add(\synth ->  Synth(\granulator, [
					\sndBuf, instrument[\buffs][0],
					\dens, 10,
					\sync, 0.75,
					\gDur, 100,
					\durDev, 1.0,
					\rate, 1,
					\rateDev, 1,
					\bufPos, 0.2,
					\bufPosDev, 0,
					\envGrain, -1,
					\panC, 0,
					\panSpread, 0.5, // in mono, pan is ignored
					\amp, 0.0,
					\out, instrument[\busSynth][\fx]
				], instrument[\mainGrp]));

			});
			(interface ++ ": Nodes created").postln;"--------------------------------".postln;
		});

		// mapping of control busses on synth control parameters
		instrument.add(\makeMaps -> {
			// Wait to make sure Synth are created
			(interface ++ ": Creating mappings").postln;
			32.do{0.05.wait; "-".post;};
			"".postln;
			s.bind({

				// mappings of \granulator
				instrument[\synth].map(\dens, instrument[\busSynth]["dens"]);
				// ~synth.map(\sync, ~busSynth["sync"]);
				instrument[\synth].map(\gDur, instrument[\busSynth]["gDur"]);
				// ~synth.map(\durDev, ~busSynth["durDev"]);

				// mappings of \triBand
				instrument[\triBandSynth].map(\gainLow, instrument[\busSynth]["gainLow"]);

				// mappings of \reverb
				instrument[\revSynth].map(\mix, instrument[\busSynth]["revMix"]);
				instrument[\revSynth].map(\room, instrument[\busSynth]["revRoom"]);
				instrument[\revSynth].map(\damp, instrument[\busSynth]["revDamp"]);
			});
			(interface + ": DMI READY").postln;"--------------------------------".postln;
		});

		////////////////////////////////
		// OSC message reception
		////////////////////////////////

		// FAIRE UN DICTIONNAIRE POUR ASSOCIER UN PARAM À UN BUS
		//
		instrument.add(\makeOSCdef -> {

			// GUI for battery check
			instrument.add(\batteryOSC -> "/battery/percentage");
			instrument.add(\winBatt -> Window("/" ++ instrument[\interface] ++ instrument[\batteryOSC], Rect(10, 710, 300, 32)).front);
			instrument.add(\slider -> MultiSliderView(instrument[\winBatt], Rect(0, 0, 300, 32)));
			instrument[\slider].indexIsHorizontal_(false);
			instrument[\slider].indexThumbSize_(30);
			instrument[\slider].elasticMode_(1);
			instrument[\slider].size_(1);
			instrument[\slider].isFilled_(1);
			// Battery Check
			OSCdef(instrument[\interface] ++ "/batteryCheck", {
				arg msg;
				// (~tStick ++ " Battery: " ++ (msg[1]/100)).postln;
				defer{instrument[\slider].value_([msg[1]/100])};
			},instrument[\interface] ++ instrument[\batteryOSC], recvPort: instrument[\recvPort]);

			// Assign OSC data to control busses
			instrument[\busDmi].keys.do({
				arg item, i;
				// ~busDmi[item].postln;
				OSCdef(item, {
					arg msg;
					// Remove the addres from the OSC message
					msg.removeAt(0);
					// make sure msg is an array the same size of control bus channel number (necessary?)
					msg = msg.reshape(instrument[\busDmi][item].numChannels);
					instrument[\busDmi][item].setn(msg);
				}, item, recvPort: instrument[\recvPort]);
			});

			// FSR and shakeX Calibration
			OSCdef(instrument[\interface] ++ "/calibration", {
				arg msg;
				var tog;

				instrument[\toggle] = (instrument[\toggle] + 1)%8;

				case
				{ instrument[\toggle] == 1 } {
					instrument[\mappingGrp].free; // frees mapping nodes -> cuts off sound
					instrument[\calibrationFunc].(1, instrument[\busDmi][instrument[\interface] ++ "/raw/fsr"], instrument[\calibrationVals], \fsr);
					"FSR Calibration Started".postln;

				}
				{ instrument[\toggle] == 3 } {
					instrument[\calibrationFunc].(0);
					instrument[\calibrationFunc].(1, instrument[\busDmi][instrument[\interface] ++ "/instrument/shakexyz"].subBus(0), instrument[\calibrationVals], \shakeThresh);
					"FSR Calibration Completed".postln;
					"Shake Threshold Calibration Started".postln;

				}
				{ instrument[\toggle] == 5 } {
					instrument[\calibrationFunc].(0);
					instrument[\calibrationFunc].(1, instrument[\busDmi][instrument[\interface] ++ "/instrument/shakexyz"].subBus(0), instrument[\calibrationVals], \shakeMax);
					"Shake Threshold Calibration Completed".postln;
					"Maximum Shake Calibration Started".postln;

				}
				{ instrument[\toggle] == 7 } {
					instrument[\calibrationFunc].(0);
					"Maximum Shake Calibration Completed".postln;
					instrument[\makeBusMappings].();
				}
			}, instrument[\interface] ++ "/instrument/button/tap", recvPort: instrument[\recvPort]);

			"--------------------------------".postln;(interface + ": OSCdef created").postln;"--------------------------------".postln;"".postln;
		});
	});
	// end of \specificFunctions function

	////////////////////////////////
	//4. register functions with ServerBoot/Quit/Tree
	////////////////////////////////

	// declare a function for registering functions
	instrument.add(\functionsRegister -> {
		ServerBoot.add(instrument[\makeBuffers]);
		ServerBoot.add(instrument[\makeBusses]);
		ServerBoot.add(instrument[\makeOSCdef]);
		(interface + ": Functions registered").postln;
	});
	// end of \functionsRegister function

	////////////////////////////////
	//5. boot server
	////////////////////////////////

	// waitForBoot executed in the main SC file

	////////////////////////////////
	//6a. SynthDefs
	////////////////////////////////

	// declare a function for adding SynthDefs to the server
	instrument.add(\synthDefServerAdd -> {

		// Granulator SynthDef
		~synthDefMaker.(\granulator, {
			arg dens=10, sync=1, gDur=100, durDev=1, sndBuf=nil, rateDev=1,
			bufPos=0, bufPosDev=0, envGrain=(-1),
			panC=0, panSpread=0,
			gate=1, amp=0.4,
			atk=0.1, rel=1.0,
			out=0;
			var trig, durCtrl, rateGen, rate, rateCtrl, posCtrl, panCtrl, sig, envDyn;

			// array of triggers (size is maximum number of streams)
			// trig = GaussTrig.kr(dens/1 ! 1, 1-sync);
			trig = GaussTrig.kr(dens, 1-sync);

			// convert grain duration from ms to s
			gDur = gDur/1000;
			durCtrl = gDur * LFNoise1.kr(100).exprange(1/durDev, durDev);

			// rate as random value in an array ||||WIP||||
			rateGen = Drand(\rates.kr(instrument[\setRates][0]), inf);
			// rateGen = Drand(\rates.kr(~setRates[0]), inf);
			rate = Demand.kr(trig, 0,rateGen);

			// rate + random deviation
			rateCtrl = rate * LFNoise1.kr(100).exprange(1/rateDev, rateDev);

			// randomize grain position
			posCtrl = LFNoise1.kr(100).bipolar(bufPosDev); // deviation, bufPosDev is normalized
			posCtrl = bufPos + posCtrl; // initial position +deviation

			panCtrl = panC + LFNoise1.kr(10).bipolar(panSpread);


			sig = GrainBuf.ar(
				instrument[\audioChan], // the number of channels to output. If 1, mono is returned and pan is ignored.
				trig,
				durCtrl,
				sndBuf,
				rateCtrl,
				posCtrl,
				2,
				panCtrl,
				envGrain,
				512
			);
			envDyn = EnvGen.kr(Env.asr(atk, 1.0, rel), gate, doneAction:2);

			sig = sig * envDyn * amp;
			// sig.poll;
			Out.ar(out, sig);
		});

		// 3 band filter -> declared in main SC file

		// reverb -> declared in main SC file

	});
	// end of \synthDefs function

	////////////////
	//6b. Register remaining functions
	////////////////

	// declare remaining functions
	instrument.add(\remainingFunctions -> {

		// Create audio Synth then wait for command to be completed
		ServerTree.add(instrument[\makeNodes]);
		s.sync;

		// Create mapping Synth then wait for command to be completed
		ServerTree.add(instrument[\makeBusMappings]);
		s.sync;

		// Maps Synth parameters to control busses
		ServerTree.add(instrument[\makeMaps]);
	});
	// end of \remainingFunctions


	////////////////////////////////
	// return the instrument dictionary
	////////////////////////////////
	instrument;
}
)
