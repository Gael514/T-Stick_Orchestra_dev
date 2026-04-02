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

		// project path
		instrument.add(\projectPath -> PathName.new(thisProcess.nowExecutingPath).parentPath);

		// List of DMI control parameters [OSC address, size, mapped or not]
		instrument.add(\tStickParam -> [
			["/raw/capsense"                 ,      30,         ], // dedicated OSCdef
			["/raw/fsr"                      ,       1, "mapped"],
			["/raw/accl"                     ,       3, "mapped"],
			["/raw/gyro"                     ,       3, "mapped"],
			["/raw/magn"                     ,       3,         ],
			["/instrument/shakexyz"          ,       3, "mapped"],
			["/instrument/squeeze"           ,       1,         ],
			["/instrument/touch/all"         ,       1,         ],
			["/instrument/touch/top"         ,       1,         ],
			["/instrument/touch/middle"      ,       1,         ],
			["/instrument/touch/bottom"      ,       1,         ],
			["/instrument/touch/discrete"    ,      30,         ],
			["/instrument/jabxyz"            ,       3,         ],
			["/instrument/brush"             ,       1, "mapped"],
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

		// Number of partials
		instrument.add(\numPartials -> 15);

		// timbre presets
		// [harmo, rq, ampMat, freqMuls..., amps..., timeScale...]
		instrument.add(\timbre -> Dictionary.newFrom([
			\p1bell,
			[
				1.0, 0.001, 20.dbamp,
				[1.0, 1.0, 0.844, 0.750, 0.826, 1.011, 1.228, 1.366, 1.504, 1.640, 1.782, 1.0, 1.0, 1.0, 1.0],
				[0.4, 1.0, 0.6, 0.4, 0.7, 0.6, 0.5, 0.1, 0.05, 0.01, -120.dbamp, -120.dbamp, -120.dbamp, -120.dbamp, -120.dbamp],
				Array.fill(instrument[\numPartials], 1.0)
			].flat,
			\p2glass,
			[
				1.0, 0.001, 20.dbamp,
				[0.5, 1.0, 1.266, 1.5, 2.066, 3.033, 4.3, 5.467, 6.767, 8.2, 9.8, 1.0, 1.0, 1.0, 1.0],
				[0.4, 1.0,   0.6, 0.4,   0.9,   0.8, 0.75,  0.5,   0.3, 0.2, 0.15, -120.dbamp, -120.dbamp, -120.dbamp, -120.dbamp],
				Array.fill(instrument[\numPartials], 1.0)
			].flat,
			// \p3nuage,
			// [
			// 	1.2, 0.001, 10.dbamp,
			// 	Array.rand(instrument[\numPartials], 0.99, 1.01),
			// 	Array.geom(instrument[\numPartials], 1.0, 0.7).normalizeSum,
			// 	Array.fill(instrument[\numPartials], 1.0)
			// ].flat,
			\p4drone,
			[
				2.05, 0.050, 6.dbamp,
				Array.rand(instrument[\numPartials], 0.99, 1.01),
				Array.geom(instrument[\numPartials], 1.0, 0.25).normalizeSum,
				Array.fill(instrument[\numPartials], 1.0)
			].flat,
			// \p5rumble,
			// [
			// 	0.01, 0.200, 20.dbamp,
			// 	[1] ++ Array.rand(instrument[\numPartials]-1, -3, 3).midiratio,
			// 	Array.geom(instrument[\numPartials], 1.0, 0.95).normalizeSum,
			// 	Array.fill(instrument[\numPartials], 1.0)
			// ].flat,
			// \p6rumblebis,
			// [
			// 	2.05, 0.050, 12.dbamp,
			// 	[1] ++ Array.rand(instrument[\numPartials]-1, -3, 3).midiratio,
			// 	Array.geom(instrument[\numPartials], 1.0, 0.95).normalizeSum,
			// 	Array.fill(instrument[\numPartials], 1.0)
			// ].flat,
			// \rumble3,
			// [
			// 	2.05, 0.050, 34.dbamp,
			// 	[1] ++ Array.rand(instrument[\numPartials]-1, -12, 12).midiratio,
			// 	Array.fill(instrument[\numPartials], 1).normalizeSum,
			// 	Array.fill(instrument[\numPartials], 1.0)
			// ].flat,
			// \woodPerc,
			// [
			// 	1.2, 0.01, 60.dbamp,
			// 	Array.fill(instrument[\numPartials], 1.0),
			// 	Array.geom(instrument[\numPartials], 1.0, 0.7).normalizeSum,
			// 	Array.geom(instrument[\numPartials], 1.0, 0.25)
			// ].flat,
			// \stonePerc,
			// [
			// 	0.001, 0.01, 20.dbamp,
			// 	Array.fill(instrument[\numPartials], 1.0),
			// 	Array.geom(instrument[\numPartials], 1.0, 0.7).normalizeSum,
			// 	Array.geom(instrument[\numPartials], 1.0, 0.25),
			// ].flat
		]);
		);

		// Sorted timbre names
		instrument.add(\sortedTimbre -> instrument[\timbre].keys.asArray.sort);

		// List of sound synthesis control parameters [, [intial values], mapped or not]
		instrument.add(\synthParam -> [
			["freq"          ,                                                          [ 220 ],         ],
			["harmo"         ,                                                            [ 1 ], "mapped"],
			["freqMuls"      ,                          Array.fill(instrument[\numPartials], 1),         ],
			["envSel"        ,                                                            [ 0 ],         ],   // SUPPRIMÉ???
			["ampMat"        ,                                                          [ 1.0 ], "mapped"],   // REMPLACÉ PAR PRESET
			["amps"          , Array.fill(instrument[\numPartials], 1/instrument[\numPartials]),         ],
			["amp"           ,                                              Array.fill(6, 0.4), "mapped"],  // each key can have a different loudness
			["pos"           ,                                                          [ 0.7 ],         ],
			["rq"            ,                                                          [ 0.1 ],         ],
			["gate"          ,                                    [ 1 ],         ],
			["timeScale"     ,                                    [ 1 ],         ],
			["atk"           ,                                  [ 0.1 ],         ],
			["rels"          ,                         Array.fill(6, 1), "mapped"],
			["revMix"        ,                                 [ 0.33 ], "mapped"],
			["revRoom"       ,                                  [ 0.5 ], "mapped"],
			["revDamp"       ,                                  [ 0.2 ], "mapped"],
			["gainLow"       ,                                    [ 1 ], "mapped"],
			["gainMid"       ,                                    [ 1 ], "mapped"],
			["gainHigh"      ,                                    [ 1 ], "mapped"],
			["descriptors"   ,                         Array.fill(5, 0),         ],
			["timbre"        ,           instrument[\timbre].asArray[0], "mapped"],
			["partialsAmod"  ,                          Array.fill(instrument[\numPartials], 1), "mapped"],
			["partialsFmod"  ,                          Array.fill(instrument[\numPartials], 1), "mapped"],
			["rqMod"         ,                                    [ 1 ], "mapped"],
			["presetSel"     ,                                    [ 0 ], "mapped"], // Bus for timbre preset selection
			["dustDens"      ,                                [ 50000 ], "mapped"],
			["dustAmp"       ,                              [ 0.dbamp ], "mapped"],
			["vibratoStrips" ,                         Array.fill(7, 0), "mapped"],
			["vibrato"       ,                         Array.fill(6, 1), "mapped"]
		]);


		// 11 notes: 2 octaves of minor penta scale
		instrument.add(\minorPenta -> (110 * [1, 6/5, 4/3, 3/2, 7/4, 2]));

		// note state: noteOn/noteOff
		instrument.add(\noteState -> Array.fill(6, 0));

		// control area state
		instrument.add(\ctrlState -> 0);

		// octave control parameter (increments calculated in OSCdef)
		instrument.add(\synthOct -> 0);

		// Minimum and maximum touch sensor values
		instrument.add(\touchMin -> Array.fill(30, 1e12 ));
		instrument.add(\touchMax -> Array.fill(30, -1e12 ));
		// TEMPORARY
		instrument[\touchMin] = Array.fill(30, 0);
		instrument[\touchMax] = [801.6, 1355.8, 1297.4, 1002, 698, 596, 654, 655, 667.4, 745, 781, 799, 771, 799.6, 717.6, 806, 847, 849, 890, 926, 977, 750.8, 670, 991, 991, 1029, 1009, 1047, 1463.8, 1380.4];

		// Turn on/off calibration
		instrument.add(\toggle -> 0);

		// Dictionnary containing calibration results
		instrument.add(\calibrationVals -> Dictionary.with(*[
			\fsr -> [0, 4095],
			\shakeThresh -> [0, 2],
			\shakeMax -> [0, 6]
		]));
		//

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

		// Buffers creation
		instrument.add(\makeBuffers -> {
			// Create a buffer to store timbre presets - from presets names in alphabetical order
			instrument.add(\bufPreset ->
				Buffer.loadCollection(s,
					(instrument[\sortedTimbre].collect{|i| instrument[\timbre][i]}).flat
				)
			);
			"".postln;"--------------------------------".postln; (interface + ": Buffers created").postln;"--------------------------------".postln;
		});

		// descriptor calculation function
		instrument.add(\acssk -> {
			arg array = [];
			var area=nil, centroid=nil, spread=nil, skewness=nil, kurtosis=nil;

			// Include a condition to avoid division by zero
			if(array.sum > 0, {
				// area calculation (input array must be scaled appropriately to return a normalized area value between 0 and 1)
				area = array.sum; //
				// normalized centroid calculation
				centroid = (array / array.sum * Array.series(array.size) / (array.size - 1)).sum;
				// spread
				spread = ( (array / array.sum * ( Array.series(array.size) / (array.size - 1) - centroid ).squared ).sum ).sqrt;
				(spread == 0.0 ).if(
					// skewness & kurtosis
					{
						skewness = 0;
						kurtosis = 0;
					},{
						skewness = ( (array / array.sum * ( Array.series(array.size) / (array.size - 1) - centroid ).cubed ).sum ) / spread.cubed;
						kurtosis = ( (array / array.sum * ( Array.series(array.size) / (array.size - 1) - centroid ).pow(4) ).sum ) / spread.pow(4) ;
					}
				);
			},{
				// nil
				area = 0; centroid = 0; spread = 0; skewness = 0; kurtosis = 0;
			});
			array = [area, centroid, spread, skewness, kurtosis];
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

			// // ADDITIONAL BUS CREATED NECESSARY???
			// instrument[\busDmi].add((interface ++ "/capsDiff") -> Bus.control(s, 15));

			// Dictionary of busses, keys are Synth arguments names
			// CONTROL busses
			bus = 0;
			instrument.add(\busSynth -> Dictionary.new);
			instrument[\arrayKey].value(instrument[\synthDefParam], \arg).do({
				arg item, i;

				// bus number of channels is the size of the parameter initial value
				instrument[\busSynth].add(item -> Bus.control(s, instrument[\synthDefParam][i][\init].size));
				instrument[\busSynth][item].setn(instrument[\synthDefParam][i][\init]);
				// increment total number of control busses
				bus = bus + instrument[\synthDefParam][i][\init].size;
			});
			// additional AUDIO busses for fx (reverb etc) and limiter
			instrument[\busSynth].add(\fx -> Bus.audio(s,instrument[\audioChan]));
			instrument[\busSynth].add(\lim -> Bus.audio(s,instrument[\audioChan]));
			(interface  ++" Synth control busses: "++ bus.asString).postln;
		});

		// Cretate Synth mapping the interface control busses to sound parameters control busses
		instrument.add(\makeBusMappings -> {
			s.bind({
				instrument.add(\mappingGrp -> Group.new);
				// {
				// 	// mapping for Synth parameter dustDens & dustAmp (amp correction)
				// 	//
				// 	var fsr, dens, dustAmp;
				// 	fsr = In.kr(instrument[\busDmi][interface ++ "/raw/fsr"], 1);
				// 	// map FSR values to dust density
				// 	// dens = fsr.lincurve(0, 3000, 20000, 5, -10);
				// 	dens = fsr.lincurve(1000, 4000, 5, 20000, 4);
				// 	// map density to an amplitude correction
				// 	dustAmp = dens.lincurve(5, 20000, 30.dbamp, -10.dbamp);
				// 	// dens.poll;
				// 	Out.kr(instrument[\busSynth]["dustDens"], dens);
				// 	Out.kr(instrument[\busSynth]["dustAmp"], dustAmp);
				// }.play(instrument[\mappingGrp]);

				{
					// mapping for notes vibrato / pitch modulation
					//
					var strips;
					var speedU, widthU, speedD, widthD;
					var speed, width, modU, modD, mod;

					// read normalized strip values
					strips = In.kr(instrument[\busSynth]["vibratoStrips"], 7);

					// calculate modulation speed (2 arrays of 6 values)
					// and (2 arrays of 6 values as well)
					// speed = [ strips[1..6], strips[0..5] ].lincurve(0, 0.5, 8, 18, 0, nil);
					speedU = strips[1..6].lincurve(0.1, 0.5, 12, 18, 0, nil);
					speedD = strips[0..5].lincurve(0.1, 0.5, 12, 18, 0, nil);
					// width = speed.lincurve(8, 18, 0.1, 0.5, 0, nil);
					widthU = speedU.lincurve(8, 18, 0.1, 0.5, 0, nil);
					widthD = speedD.lincurve(8, 18, 0.1, 0.5, 0, nil);

					// calculate modulation when touching the upper strip of a note
					// modulates 1 octave up when touched
					modU = LFPulse.kr(
						speedU * LFNoise1.kr(1.0!6).range(0.9, 1.1),
						0,
						widthU
					).range(1, (strips[1..6]).collect( {|i| (i > 0).if(2, 1) }) );

					// calculate modulation when touching the lower strip of a note
					// modulates 1 fourth down when touched
					modD = LFPulse.kr(
						speedD * LFNoise1.kr(1.0!6).range(0.9, 1.1),
						0,
						widthD
					).range(1, (strips[0..5]).collect( {|i| (i > 0).if(2/3, 1)} ) );

					// combine both modulations
					mod = Lag.kr(modU * modD, 0.015);
					// speedU.poll;
					// modU.poll;
					// mod.poll;
					// write on control busses
					Out.kr(instrument[\busSynth]["vibrato"], mod);
				}.play(instrument[\mappingGrp]);

				{
					// mapping for rq modulation
					//
					var fsr, rq, rqMod;
					fsr = In.kr(instrument[\busDmi][interface ++ "/raw/fsr"], 1);
					rq = In.kr(instrument[\busSynth]["timbre"].subBus(1), 1);

					// map FSR values to rq modulation coefficient
					rqMod = fsr.lincurve(1000, 4000, 1, 10, 0, \min) * rq;

					Out.kr(instrument[\busSynth]["rqMod"], rqMod);
				}.play(instrument[\mappingGrp]);

				{
					// mapping for partials modulation
					//
					var aMod, fMod, gyro, aDev, fDev, speed, aPartials, fPartials, numPartials = instrument[\numPartials];
					gyro = In.kr(instrument[\busDmi][interface ++ "/raw/gyro"], 3);
					fPartials = In.kr(instrument[\busSynth]["timbre"].subBus(3, numPartials), 3);
					aPartials = In.kr(instrument[\busSynth]["timbre"].subBus(numPartials + 3, numPartials), 3);

					aDev = (gyro.mean.linlin(-5, 5, -20, 20, nil)).dbamp;
					fDev = (gyro.mean.linlin(-5, 5, -2.midiratio, 2.midiratio, nil));
					speed = gyro.abs.mean.linlin(0, 10, 0.5, 5);

					// partials amp modulation
					aMod = LFNoise1.kr(speed.dup(numPartials)).range(aDev, aDev.reciprocal) * aPartials;

					// partials freq modulation
					fMod = LFNoise2.kr(speed.dup(numPartials)).range(fDev, fDev.reciprocal) * fPartials;

					Out.kr(instrument[\busSynth]["partialsAmod"], aMod);
					Out.kr(instrument[\busSynth]["partialsFmod"], fMod);
				}.play(instrument[\mappingGrp]);



				{
					// Mapping for timbre parameters
					//
					var gyro, switch, locking, latch;
					var thresh = [[4, 3, 3], [5, 4, 4]], ceiling = [10, 6, 8];
					var trig, selector = 0;
					var preset, base = 0, numParams, params = instrument[\timbre][\p1bell], lag = 0.5;

					// // 1st step is to read gyro values
					// gyro = In.kr(instrument[\busDmi][interface ++ "/raw/gyro"].index, 3);
					//
					// // temporary switch (Schmidt trigger)
					// // VÉRIFIER LES SIGNES DE GYRO / HOW TO INITIALIZE THE BUSSES!!!!!!
					// switch = Schmidt.kr(gyro, thresh[0], thresh[1]);
					//
					// // latch on preset
					// locking = (gyro > ceiling);
					//
					// // latch toggles between 0 & 1 when locking triggers (0 to 1)
					// latch = ToggleFF.kr(locking);
					//
					// // trig: 1 when both switch and latch are equal to 1
					// // when either is 0, trig is 0
					// trig = switch.max(latch);
					//
					// // calculate selector as a binary value 0 to 7
					// selector = Mix(trig * [1, 2, 4]);
					// // selector.poll; // selector works (adjust gyro thresholds...)

					// read preset number from bus
					selector = In.kr(instrument[\busSynth]["presetSel"], 1);


					// check if the preset selector changed value
					// Impulse.kr(0) plays a single impulse as initial trigger
					trig = Changed.kr(selector) + Impulse.kr(0);
					numParams = instrument[\busSynth]["timbre"].numChannels;

					// position to read from in the buffer
					// reminder: timbre presets are loaded in alphabetical order in the buffer
					base = selector * numParams;

					// Latch to the new values, with a lag COMMENT MAPPER LA VALEUR DE LAG
					params = Lag.kr(
						Array.fill(
							numParams, {
								arg i;
								Latch.kr(
									BufRd.kr(1, instrument[\bufPreset], base + i),
									trig
								)
						}), lag
					);
					Out.kr(instrument[\busSynth]["timbre"], params);
				}.play(instrument[\mappingGrp]);

				//
				{}.play(instrument[\mappingGrp]);

			})
		});

		// Create audio Synth
		instrument.add(\makeNodes -> {
			s.bind({
				instrument.add(\mainGrp -> Group.new);
				instrument.add(\fxGrp -> Group.after(instrument[\mainGrp]));
				instrument.add(\limGrp -> Group.after(instrument[\fxGrp]));

				// equalizer Synth
				// instrument.add(\eqSynth -> Synth(\equalization, [\in, out, \out, out, \ampMod, 0.25], instrument[\fxGrp]));
				// ~eqSynth = Synth(\equalization, [\in, 1, \out, 1, \ampMod, 0.25], ~fxGrp);


				// limiter Synth
				instrument.add(\limitSynth -> Synth(\comp, [\in, instrument[\busSynth][\fx], \thesh, -3.dbamp, \out, out], instrument[\limGrp]));

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

				// mappings


				// mappings of \triBand


				// mappings of \reverb

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
					var val;
					// Remove the addres from the OSC message
					val = msg[1..];
					// make sure msg is an array the same size of control bus channel number (necessary?)
					val = val.reshape(instrument[\busDmi][item].numChannels);
					// (item + val).postln;
					instrument[\busDmi][item].setn(val);
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

			// REVISER!!!!!!!
			////////////////////////////////
			// TOUCH SENSOR OSCdef
			////////////////////////////////

			// difference of capsense values over a 10 messages window
			// WHY HOW DOES IT WORK???
			// function to calculate the difference between max and min values in an array
			instrument.add(\funDiff -> {arg array; array.maxItem - array.minItem;});
			// function to fill a row in a 2D array with an array of values
			instrument.add(\array2DrowPut -> {arg array2D, row, array; array.do{|val, i| array2D[row, i] = val} });

			// 2D array used to store 10 consecutive values for each of 15 pairs of touch sensor strips
			instrument.add(\capsBuf -> Array2D.fromArray(15, 10, 0.dup(150)));
			instrument.add(\capsDiff -> Array.fill(15, 0));

			instrument.add(\capsense -> Array.fill(15, 0)); // NECESSARY???? DUPLICATE FROM LLINE 50.... REMOVE!!!
			// arrays for 11 notes that can be played
			instrument.add(\synthTrig -> Array.fill(11, 0));
			instrument.add(\synthArray -> Array.fill(11, nil));

			// record if the touch sensor is armed for octave incrementing
			instrument.add(\octArmed -> true);

			// threshold for brush
			instrument.add(\posBrush -> 0.15);
			instrument.add(\negBrush -> -0.15);
			instrument.add(\reArmBrush -> 0.0); // lower threshold for re-arming (when brush value decays back to 0)

			// record last time an octave brush was trigged
			instrument.add(\lastOctBrushTime -> 0);
			instrument.add(\debounceOct -> 0.25); // 250 ms debounce

			// OSCdef reads raw touch sensor values
			OSCdef.new(interface ++ "/touchTrig", {
				arg msg;
				var touchVals, normTouch, noteVal = [], noteTrig = [], noteVib, ctrlArea;
				var acssk, ctrlOn, noteOn, ctrlOff, noteOff;
				var dustDens, dustAmp, noteAmp;
				var presetSel, params;
				var octCtrl, brush, capsAtk, capsRel, amps;
				var now = SystemClock.seconds; // current time

				touchVals = msg[1..30];
				// normalizing touch sensor values
				normTouch = touchVals.linlin(instrument[\touchMin], instrument[\touchMax], 0, 1, nil);

				// keep first 3 strips values for octave control (combined with brush)
				octCtrl = normTouch[0..2];

				// create an array for note values (average of 2 consecutive strip values)
				[4, 5, 7, 8, 10, 11, 13, 14, 16, 17, 19, 20].pairsDo{|a, b|
					noteVal = noteVal.add((normTouch[a] + normTouch[b]) / 2);
				};

				// every third strip from number 3 is reserved for vibrato
				noteVib = normTouch[(3, 6..21)];
				// noteVib.round(0.1).postln;
				// write the values on a control bus
				instrument[\busSynth]["vibratoStrips"].setn(noteVib);

				// define control area
				ctrlArea = normTouch[22..29];
				// calculate descriptors for the control area
				// divide by number of strips to have A < 1
				acssk = instrument[\acssk].(ctrlArea / ctrlArea.size);

				// acssk.round(0.01).postln;
				// noteVal.round(0.01).postln;
				// normTouch.round(0.1).postln;

				// AMPLITUDE CALCULATION
				// calculate dust density from area of control surface
				// A = 0 -> impulses
				// A = 1 -> white noise
				dustDens = acssk[0].lincurve(0.1, 0.5, 5, 20000, 2, \minmax); // RETRAVAILLER

				// write on a control bus (synth will be mapped to it for continuous control of density)
				instrument[\busSynth]["dustDens"].set(dustDens);

				// calculate dustAmp, amplitude correction (higher density equivalent to white noise gets too loud)
				dustAmp = dustDens.lincurve(5, 20000, 40.dbamp, -40.dbamp, -10);

				("dust Dens" + dustDens).postln; // REMOVE!!!!
				("dust Amp" + dustAmp).postln; // REMOVE!!!!

				// calculate notes amplitude
				// dustAmp included for loudness correction
				noteAmp = noteVal.lincurve(0.0, 1.0, -60.dbamp, -10.dbamp, 0, nil) * dustAmp;
				// [acssk[0], dustDens].postln;

				// dustAmp.postln;
				// noteAmp.postln;

				// write on a control bus (synth will be mapped to it for continuous control of amplitude)
				instrument[\busSynth]["amp"].setn(noteAmp);

				// PRESET SELECTION
				// TEMPORARY - select preset based on centroid position IMPROVE!!!
				presetSel = (acssk[1] * 3).floor.clip(0, 2);

				// write preset value on control bus
				// only if area > 0 (prevent preset going back to 0 when fingers leave control area)
				if(acssk[0] > 0) {instrument[\busSynth]["presetSel"].set(presetSel)};

				// return timbre parameters
				// params = instrument[\timbre][[ \bell, \glass, \drone2, \nuage ][presetSel]];
				// instrument[\busSynth]["timbre"].setn(params);

				// Check if control area and some motes are both trigger ready
				// previous value
				// transient control state
				ctrlOn = (instrument[\ctrlState] == 0).and(acssk[0] > 0);

				ctrlOff = (instrument[\ctrlState] == 1).and(acssk[0] == 0);
				// instrument[\noteState].postln;
				// noteVal.round(0.01).postln;

				// transient note state MOVE into fi STATEMENT???
				noteOn = instrument[\noteState].collect{|item, i| (item == 0).and(noteVal[i] > 0)};
				noteOff = instrument[\noteState].collect{|item, i| (item == 1).and(noteVal[i] == 0)};

				// [ctrlOn, ctrlOff, noteOn, noteOff].postln;

				// VIBRATO CALCULATION
				// noteVib write on HOW MANY busses?
				// CALCULATE TE PAIRS HERE OR IN THE SYNTH????

				// OCTAVE CALCULATION
				// check if 1 of strips 1 or 2 is touched
				// returns 0 if all values are above 0.05, 1 otherwise
				// 0.05 is used as a threshold instead of 0, in case of unwanted (jitter?) values on touch sensor
				//
				octCtrl = octCtrl[1..2].any({ |i| i > 0.05}).asInteger;

				// get brush value
				brush = instrument[\busDmi][interface ++ "/instrument/brush"].getSynchronous();

				// combine brush with control area
				octCtrl = octCtrl * brush;

				// octave calculation logic
				// touch sensor must be armed for octave increment

				if ( (instrument[\octArmed] == true).and( (now - instrument[\lastOctBrushTime]) > instrument[\debounceOct]) ) {
					// 2 conditions to evaluate
					case
					// positive brush -> octave up
					{ octCtrl >= instrument[\posBrush] } {
						instrument[\synthOct] = instrument[\synthOct] + 1;
						// octave control must be re-armed
						instrument[\octArmed] = false;
						// update last brush time
						instrument[\lastOctBrushTime] = now;
						("octave " ++ instrument[\synthOct]).postln
					}
					// negative brush -> octave down
					{ octCtrl <= instrument[\negBrush] } {
						instrument[\synthOct] = instrument[\synthOct] - 1;
						// octave control must be re-armed
						instrument[\octArmed] = false;
						// update last brush time
						instrument[\lastOctBrushTime] = now;
						("octave " ++ instrument[\synthOct]).postln
					};
				};
				// re-arm
				if ( (instrument[\octArmed].not) && (brush == instrument[\reArmBrush]) ) {
					instrument[\octArmed] = true;
				};

				// TEMPORARY

				// NOTES TRIGGERING
				instrument[\synthArray] = noteVal.collect{
					arg item, i;
					var synth, freqDev;
					// check if ctrl area sustained and note on
					// or control area on and note sustained
					if(( (noteOn[i] == true).and(acssk[0] > 0) ).or( (noteVal[i] > 0).and(ctrlOn == true) ), {
						(noteVal[i].round(0.01) + "trigged").postln;
						("octave" ++ instrument[\synthOct]).postln; // REMOVE!!!!


						// capsAtk[i].postln;
						freqDev = Array.fill(instrument[\numPartials], {-0.25.rrand(0.25).midiratio});
						synth = Synth(\multiFiltReson, [
							// \freq, 2.pow(instrument[\synthOct]) * instrument[\minorPenta][i],
							\freq, instrument[\minorPenta][i],

							// // bell sound
							\harmo, 1,
							\freqMuls, [1.0, 1.0, 0.844, 0.75, 0.826, 1.011, 1.228, 1.366, 1.504, 1.64, 1.782, 1.0, 1.0, 1.0, 1.0] * freqDev,
							\amps, [0.4, 1.0, 0.6, 0.4, 0.7, 0.6, 0.5, 0.1, 0.05, 0.01, -120.dbamp, -120.dbamp, -120.dbamp, -120.dbamp, -120.dbamp].normalizeSum,
							\rq, 0.001,
							\ampMat, 30.dbamp,

							// \atk, capsAtk[i], // REWORK
							\atk, 0.001,
							// \decay, atk.lincurve(0.001, 0.5, 0.3, 0.001), // TBC!!!!
							\decay, 0.3,
							// \sus, 0.7/peak; // TBC!!!!!!!!
							\sus, 0.7,
							\amp, -10.dbamp,
							\out, out
						], instrument[\mainGrp]);
						("Note: " ++ instrument[\minorPenta][i].round(0.1) ++ " Hz").postln;
						// ("Attack: " ++ capsAtk[i] ++ " s").postln;

						// map \amp to control busses
						synth.map(\amp, instrument[\busSynth]["amp"].subBus(i));

						// map \fDev to control bus
						synth.map(\fDev, instrument[\busSynth]["vibrato"].subBus(i)); // UNMAP AT RELEASE???

						// map \dustDens to control bus
						synth.map(\dustDens, instrument[\busSynth]["dustDens"]);

						// map timbre parameters [harmo, rq, ampMat, freqMuls..., amps..., timeScale...] to control busses
						synth.map(\harmo,
							instrument[\busSynth]["timbre"].subBus(0)); // 1 channel
						synth.map(\rq,
							instrument[\busSynth]["rqMod"]); // 1 channel
						synth.map(\ampMat,
							instrument[\busSynth]["timbre"].subBus(2)); // 1 channel
						synth.map(\freqMuls,
							// instrument[\busSynth]["timbre"].subBus(3, instrument[\numPartials])); // n channels
							instrument[\busSynth]["partialsFmod"]); // n channels
						synth.map(\amps,
							// instrument[\busSynth]["timbre"].subBus(instrument[\numPartials] + 3, instrument[\numPartials])); // n channels
							instrument[\busSynth]["partialsAmod"], instrument[\numPartials]); // n channels
						synth.map(\timeScale,
							instrument[\busSynth]["timbre"].subBus(2 * instrument[\numPartials] + 3, instrument[\numPartials])); // n channels

					}
					,{
						//
						synth = instrument[\synthArray][i];
					}
					);
					// release only if there is a synth
					if((noteOff[i] == true).or(ctrlOff == true).and(instrument[\synthArray][i].notNil), {
						var relAmp = instrument[\busSynth]["amp"].subBus(i).getSynchronous();
						("amp value at release " ++ relAmp.round(0.01)).postln;
						// update \rels
						//
						// NEED TO MAINTAIN THE AMPLITUDE VALUE AFTER REMOVING FINGER -> UNMAP
						// synth.unmap(\amp);
						synth.set(\amp, relAmp);
						// calculation of release time at release.....
						// reads amp values for each note
						capsRel = instrument[\busSynth]["amp"].subBus(i).getSynchronous().lincurve(0, 1, 2, 6, 4);
						("Release duration " ++ capsRel.round(0.01)).postln;
						synth.set(\rels, capsRel * Array.fill(instrument[\numPartials], {1.33.rrand(1.33.reciprocal)}));
						//
						// release Synth
						synth.set(\gate, 0);
						synth = nil;
					});
					synth;
				};


				// update state of control area
				instrument[\ctrlState] = acssk[0].roundUp(1.0);
				instrument[\noteState] = noteVal.roundUp(1.0);

			}, interface ++ "/raw/capsense", recvPort: port);





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

		// Filter SynthDef
		~synthDefMaker.(\multiFiltReson, {
			arg out=0, freq=220, fDev=1.0, harmo=1.0, rq=0.1, atk=0.1, decay=0.1, sus=0.7, ampMat=1.0, envSel=0, amp=0.7, gate=1, pos=0.0, dustDens=50000;
			var envT, envN, env, sigMat, sigFilt, freqMax, peak;

			// envT = EnvGen.kr(Env.asr(atk, 1.0, \rels.kr( Array.fill(~numPartials, 1) )), gate); // plusieurs gates????
			// envN = EnvGen.kr(Env.perc(atk, \rels.kr( Array.fill(~numPartials, 1) )));
			// env = Select.kr(envSel, [envN, envT]);

			peak = atk.lincurve(0.001, 0.5, 1, 0.7); // AFFINER LES COEFFICIENTS
			env = EnvGen.kr(Env.adsr(atk, decay, sus, \rels.kr( Array.fill(instrument[\numPartials], 10) ), 1.0), gate, timeScale: \timeScale.kr(Array.geom(instrument[\numPartials], 1.0, 1.0)));
			// env[0].poll;
			// sigMat = WhiteNoise.ar;
			sigMat = Dust2.ar(dustDens);
			sigFilt = Mix.ar(
				BPF.ar(
					sigMat,
					Array.series(
						// frequencies
						instrument[\numPartials],
						freq,
						freq * harmo
					) * \freqMuls.kr( Array.fill(instrument[\numPartials], 1)) * fDev,
					rq,
					\amps.kr( Array.fill(instrument[\numPartials], 1/instrument[\numPartials]) ) * ampMat
				) * env
			); //rq multiplié par amps (ou autre Array)
			freqMax = freq * ( (instrument[\numPartials]-1)*harmo +1);
			sigFilt = BLowPass.ar(sigFilt, 0.5*freqMax, 0.3); // RETRAVAILLER!!!
			// Libérer le synth seulement quand toutes les enveloppes sont closes
			FreeSelf.kr(DetectSilence.ar(sigFilt, -100.dbamp, time: 1.0)); // Freeself contrôlé par Mix(sig): 1 seul signal!
			Out.ar(out, PanAz.ar(2, sigFilt, pos, amp) );
		});

		// multiband equalizer TBC USAGE
		~synthDefMaker.(\equalization, {
			arg out=0, in=0, ampMod=0.25;
			var sig, dry;
			dry = In.ar(in, 1);
			sig = BPF.ar(
				dry,
				\freqs.kr(Array.series(10, 100, 1000)) * LFNoise2.kr(\modF.kr(Array.rand(10, 0.5, 2.0))).range(-3.dbamp, -3.dbamp),
				LFNoise2.kr(\modQ.kr(Array.rand(10, 0.5, 2.0))).range(0.1, 1.0)
			);
			sig = sig * LFNoise2.kr(\modA.kr(Array.rand(10, 0.5, 2.0))) * ampMod;
			sig = Mix.ar(sig);
			sig = dry + sig;
			Out.ar(out, sig);
		});

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
